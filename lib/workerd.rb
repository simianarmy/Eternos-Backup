# $Id$

require 'mq'
require 'mq_recover_patch'
require 'ruote_external_workitem'
#require 'active_support/core_ext/class/inheritable_attributes'
require 'forwardable'
require 'backup_helper'
require 'system_timer'
require 'redis'
require 'thread' # Mutex
require File.join(RAILS_ROOT, 'lib/eternos_backup/site_data')
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

  # Base class for all site-specific worker classes
  class Queue
    class BackupSourceNotFoundException < Exception; end
    class BackupSourceExecutionFlood < Exception; end
    
    include BackupDaemonHelper

    @@consecutiveJobExecutionTime = 60 # in seconds
    
    attr_reader :redis

    def initialize(env, options={})
      log_info "Starting up worker daemon"
      load_rails_environment env
      @redis = Redis.new # Connect to Redis server
    end

    def run
      log_info "Connecting to MQ..."
      jobs = 0
      
      MessageQueue.start do
        AMQP.fork(MAX_SIMULTANEOUS_JOBS) do
          log_info "worker #{MQ.id} started"
          
          # Subscribe to queue in topic exchange and use key name 
          # (if available) to determine worker class				
          MQ.prefetch(1)
          
          # Operate inside thread for asynchronous publishing ?
          Thread.new do
            q = MessageQueue.backup_worker_subscriber_queue('*')

            # Subscribe to the queue
            log_debug "Connecting to worker queue #{q.name}"
            q.subscribe(:ack => true) do |header, msg|
              unless AMQP.closing?
                unless purge_queue?
                  msg = process_job(msg)
                   # send result back to publisher
                  send_results(msg)
                end
                # always acknowledge message
                header.ack
                sleep(0.5) # Give EM a chance to publish
              end
            end
          end
          
          Thread.new do
            # Subscribe to really long-running jobs queue
            long_q = MessageQueue.long_backup_worker_queue
            log_debug "Connecting to worker queue #{long_q.name}"
            long_q.subscribe(:ack => true) do |header, msg|
              unless AMQP.closing?
                if purge_queue?
                  header.ack
                else
                  msg = process_job(msg)
              
                  # Long jobs can be requeued if they work in batches, so if they 
                  # need more work, we don't acknowledge the message and reprocess 
                  # using recover method below
                  unless reprocess_job?(msg)
                    send_results(msg)
                    header.ack
                  else
                    DaemonKit.logger.info "Job not finished...Requeuing."
                  end
                end
                sleep(0.5) # Give EM a chance to publish
              end
            end # subscribe
            # Make sure requeue timer doesn't cause BackupSourceExecutionFlood errors
            EM.add_periodic_timer(@@consecutiveJobExecutionTime*2) { long_q.recover(:requeue => true) }
          end
        end # AMQP.fork

        
        # Simple keep-alive ping
        #DaemonKit::Cron.scheduler.every("5m") do
        #  MQ.queue('remote-participant-status' ).publish( "backup worker daemon OK" )
        #end
      end # MessageQueue.start
    end

    def finish
      EM.forks.each {|pid| Process.kill("KILL", pid)}
      EM.stop { AMQP.stop }
    end

    protected

    def process_job(msg)
      log_debug "Received workitem"
      # Running worker in thread allows EM to publish messages while thread is sleeping
      # Important when worker needs to send jobs to another subscriber
      # during execution.	 If not run in thread, jobs won't be published
      # until end of worker execution.
      # Make sure worker calls Kernel.sleep periodically in loop

      # Another benefit to running worker in thread is that subscriber loop can 
      # continue receiving messages, allowing daemon to run all backup jobs in 
      # parallel, which is what we want.
      work = Proc.new {
        # Use daemon-kit safely method to wrap blocks with exception-handling code
        # See DaemonKit::Safety for config options
        wi = safely { process_message(msg) }
        # Force AR to give up connection thread in case safely{} fucks up ar_thread_patches work
        ActiveRecord::Base.clear_active_connections!
        # Return updated workitem
        wi
      }
      # Do work in thread unless we are in test environment
      if DaemonKit.env == 'test'
        work.call
      else
        if THREADING_JOBS_ENABLED
          log_info "Running worker thead..."
          # Will it return expression value?
          Thread.new { work.call }
        else
          log_info "Running worker without thread..."
          work.call
        end
      end
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
      redis.set job_start_key(wi), job.created_at.to_s
                     
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

      worker = WorkerFactory.create_worker(workitem.source_name, job)

      unless worker.authenticate
        auth_failed worker.errors.to_s
        return false
      end

      worker.run workitem.options

      save_error worker.errors.to_s if worker.errors.any?
      # Return backup success status
      worker.errors.empty?
    end

    def send_results(response)
      feedback_q_name = response['reply_queue']
      MQ.queue(feedback_q_name).publish(response.to_json)
      log_debug "Published response to queue: " + feedback_q_name
    end

    def purge_queue?
      File.exists? File.join(DaemonKit.root, 'tmp', PURGE_QUEUE_FILE)
    end
    
    # Returns true if last execution time too recent for this backup source job - the same job can be repeated 
    # when this process fails unexpectedly and is unable to ACK & RabbitMQ puts the job back on the queue.
    def recent_job?(wi)
      # In case of large # of queued jobs for the same source, we check for the latest 
      # and skip processing if too close in time to the last one      
      return false unless last_job_time = redis.get(job_start_key(wi))
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
      wi['worker']['reprocess']
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
