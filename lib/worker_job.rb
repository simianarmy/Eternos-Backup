# $Id$

require 'system_timer'
require File.join(File.dirname(__FILE__), 'workers/base') 
require File.join(File.dirname(__FILE__), 'workers/email_worker')
require File.join(File.dirname(__FILE__), 'workers/facebook_worker')
require File.join(File.dirname(__FILE__), 'workers/picasa_worker')
require File.join(File.dirname(__FILE__), 'workers/rss_worker')
require File.join(File.dirname(__FILE__), 'workers/twitter_worker')

module BackupWorker
  Workers = [BackupWorker::Email, 
    BackupWorker::Facebook, 
    BackupWorker::Picasa, 
    BackupWorker::RSS, 
    BackupWorker::Twitter]
  
  # Singleton cache object
  class Cache  
    require 'redis'
    extend Forwardable
    include Singleton
    
    attr_reader :cache
    
    def initialize
      @cache = Redis.new :thread_safe => true 
    end
    
    def_delegators :@cache, :set, :get
  end
  
  @@cache = Cache.instance
  mattr_reader :cache
  
  # Helper class for parsing ruote engine incoming workitems and 
  # formatting response sent back on amqp queue
  class WorkItem
    attr_reader :source_id, :job_id, :source_name, :options, :wi
    extend Forwardable
    def_delegator :@wi, :[]

    # parses ruote engine message into a RuoteExternalWorkitem
    def initialize(msg)
      @wi = RuoteExternalWorkitem.parse(msg)
      @source_name	= @wi['target']['source']
      @source_id		= @wi['target']['id'] rescue nil
      @job_id				= @wi['job_id']
      @options			= @wi['target']['options'] rescue nil
      @wi['worker'] ||= {}
    end

    def save_message(msg)
      (@wi['worker']['message'] ||= []) << msg
    end

    def save_success
      save_status(200)
    end

    def save_error(err)
      save_status(500)
      (@wi['worker']['error'] ||= []) << err
    end

    def reprocess!
      @wi['worker']['reprocess'] = true
    end
    
    def to_json
      @wi.to_json
    end

    def to_s
      @wi.short_fei
    end

    private

    def save_status(status)
      @wi['worker']['status'] = status
    end
  end

  # WorkerFactory class
  # Returns new Worker class object based on job parameters
  class WorkerFactory
    def self.create_worker(target, backup_job)
      obj = BackupWorker::Workers.select do |worker|
        worker.site == target
      end
      raise "Unkown backup worker name: #{target}" if obj.empty?

      # Instantiate worker class 
      obj.first.new(backup_job)
    end
  end
  
  # Worker
  # Class containing core logic for controlling backup job execution
  # Determines backup worker to instantiate & sends response back to ruote.
  #
  class Worker
    include EM::Deferrable

    class BackupSourceNotFoundException < Exception; end
    class BackupSourceExecutionFlood < Exception; end
    
    include BackupDaemonHelper

    @@consecutiveJobExecutionTime = 60 # in seconds
    @@feedback_queue = nil
    
    def initialize(msg)
      @msg = msg 
    end
    
    # Execute worker
    def run
      # Do the backup
      wi = process_job(@msg)
      
      # Send backup results to Ruote participant listener
      # Whenever Ruote wants to start working again...we'll use this
      #send_results(wi)
      
      # EM::Deferrable methods
      # Call this to signal job success.  Will trigger callback method
      if reprocess_job?(wi)
        log_info "Sending deferred failed"
        set_deferred_status :failed
      else
        log_info "Sending deferred succeeded"
        set_deferred_status :succeeded
      end
    end
    
    protected
    
    def process_job(msg)
      # Use daemon-kit safely method to wrap blocks with exception-handling code
      # See DaemonKit::Safety for config options
      wi = safely { process_message(msg) }
      # Force AR to give up connection thread in case safely{} fucks up ar_thread_patches work
      ActiveRecord::Base.clear_active_connections!
      # Return updated workitem
      wi
    end

    # Send workitem json response back to ruote amqp participant response listener
    def send_results(response)
      feedback_q_name = response['reply_queue']
      @@feedback_queue ||= MQ.queue(feedback_q_name)
      @@feedback_queue.publish(response.to_json)
      
      log_debug "Published response to queue: " + feedback_q_name
    end
    
    # Parses incoming workitem & runs backup method on worker class.
    # Returns WorkItem object
    def process_message(msg)
      write_thread_var :wi, wi = WorkItem.new(msg) # Save workitem object for later
      log_info "Processing incoming workitem: #{workitem.to_s}"

      begin
        run_backup_job(wi) do |job|
          # Start backup job & pass info in BackupSourceJob
          if backup(job) 
            save_success_data
          end
        end
      rescue BackupSourceExecutionFlood => e
        # Too many jobs should not be an error
        save_success_data e.to_s
        log_info "*** BackupSourceExecutionFlood error"
      rescue BackupWorker::Base::BackupIncomplete => e
        workitem.reprocess!
        log_info "*** Backup job requires reprocessing"
      rescue Exception => e
        save_error "#{e.to_s}\n#{e.backtrace}"
        log_info "*** Unexpected error #{e.message}"
      end
      log_info "Done processing workitem"

      workitem
    end

    # Creates BackupSourceJob based on workitem values passed, yields it to caller block.
    # Saves finish time and saves it.
    def run_backup_job(wi)
      # In case of large # of queued jobs for the same source, we check for the latest 
      # and skip processing if too close in time to the last one
      if recent_job? wi
        raise BackupSourceExecutionFlood.new("Backup source backup job run too recently to run now")
      end
      if DISABLE_LONG_DATASETS && (get_dataset(wi) != EternosBackup::SiteData.defaultDataSet)
        raise BackupSourceExecutionFlood.new("Disabling long running data backups")
      end

      # Fetch or create existing BackupSourceJob record
      job = nil
      BackupSourceJob.transaction do 
        unless job = BackupSourceJob.find(:first, :conditions => {:backup_job_id => wi.job_id, :backup_source_id => wi.source_id, :backup_data_set_id => get_dataset(wi)})
          # BackupSourceJob.create generates fucked up error: "unknown attribute: backup_source_id" ???!!
          # Try using new/save as workaround
          job = BackupSourceJob.new
          job.backup_job_id = wi.job_id
          job.backup_source_id = wi.source_id
          job.backup_data_set_id = get_dataset(wi)
          job.status = BackupStatus::Running
          job.save
        end
      end

      unless job && job.backup_source
        raise BackupSourceNotFoundException.new("Unable to find backup source #{wi.source_id} for backup job #{wi.job_id}")
      end
      # Save job's start time to cache
      BackupWorker.cache.set job_start_key(wi), job.created_at.to_s
                     
      job.status = BackupStatus::Success # successful unless an error occurs later
      
      yield job

      log_debug "***DONE WITH JOB SAVING IT NOW***"
      BackupSourceJob.cleanup_connection { job.finished! }
    end

    # Main work method, child classes implement core actions
    # authentication: authenticate
    # source-specific backup actions: actions
    def backup(job)
      write_thread_var :job, job
      write_thread_var :source, job.backup_source

      worker = BackupWorker::WorkerFactory.create_worker(workitem.source_name, job)

      unless worker.authenticate
        auth_failed worker.errors.to_s
        return false
      end

      worker.run workitem.options

      save_error worker.errors.to_s if worker.errors.any?
      # Return backup success status
      worker.errors.empty?
    end
    
    # Returns true if last execution time too recent for this backup source job - the same job can be repeated 
    # when this process fails unexpectedly and is unable to ACK & RabbitMQ puts the job back on the queue.
    def recent_job?(wi)
      # In case of large # of queued jobs for the same source, we check for the latest 
      # and skip processing if too close in time to the last one      
      return false unless last_job_time = BackupWorker.cache.get(job_start_key(wi))
      DaemonKit.logger.debug "Got job time from Redis: #{last_job_time}"
      
      (Time.now - Time.parse(last_job_time)) < @@consecutiveJobExecutionTime
            
      # return false unless last_job_time = BackupSourceJob.cleanup_connection do
      #         # there should always be a dataType option now..
      #         if last_job = BackupSourceJob.backup_source_id_eq(wi.source_id).backup_data_set_id_eq(get_dataset(wi)).newest
      #           last_job.created_at
      #         end
      #       end
    end

    def job_start_key(wi)
      [wi.source_id, get_dataset(wi), 'start'].join(':')
    end
    
    def reprocess_job?(wi)
      wi['worker']['reprocess'] rescue false
    end
    
    def save_success_data(msg=nil)
      workitem.save_success
      workitem.save_message(msg) if msg
    end

    def save_error(err)
      log :error, "Backup error: #{err}"

      # Save error to job record if one was created 
      if j = thread_job
        BackupSourceJob.cleanup_connection do
          j.status = 0
          (j.error_messages ||= []) << err
          j.save
        end
      end
      workitem.save_error(err) # Save error in workitem
    end

    def auth_failed(error='')
      error = 'Login failed' if error.blank?
      BackupSource.cleanup_connection do
        backup_source.login_failed! error
      end
      save_error error
    end

    # Returns data set options from workitem, or default
    def get_dataset(wi)
      if wi.options && wi.options['dataType']
        wi.options['dataType']
      else
        EternosBackup::SiteData.defaultDataSet
      end
    end

    # Helper methods to access thread-local vars
    def thread_var(sym)
      #puts "thread get: Current thread: #{Thread.current} var: #{sym.to_s}"
      Thread.current[sym]
    end

    def write_thread_var(sym, val)
      #puts "thread write: Current thread: #{Thread.current} var: #{sym.to_s}"
      Thread.current[sym] = val
    end

    def thread_job
      thread_var :job
    end

    def thread_source
      thread_var :source
    end

    def thread_workitem
      thread_var :wi
    end

    def backup_source
      thread_source
    end

    def backup_job
      thread_job
    end

    def workitem
      thread_workitem
    end

  end
end