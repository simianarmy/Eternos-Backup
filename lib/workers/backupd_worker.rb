# $Id$

require 'rubygems'
require 'benchmark'
require 'custom_external_workitem' # Hoping to fix JSON crazyiness

module BackupWorker
  # Helper methods for all worker classes
  module Helper
    def load_rails_environment(env)
      mark = Benchmark.realtime do
        require File.join(RAILS_ROOT, 'config', 'environment')
      end
      log_info "loaded rails environment... #{mark} seconds"
    end
    
    def log_info(*args)
      log :info, *args
    end
    
    def log_debug(*args)
      log :debug, *args
    end
    
    def log(level, *args)
      case level
      when :debug
        DaemonKit.logger.debug *args
      when :info
        DaemonKit.logger.info *args
      when :warn
        DaemonKit.logger.warn *args
      when :error
        DaemonKit.logger.error *args
      end
    end
  end
  
  # Job workitem object parses amqp message into a RuoteExternalWorkitem
  class WorkItem
    attr_reader :source_id, :job_id
    
    def initialize(msg)
      @wi = RuoteExternalWorkitem.parse(msg)
      @source_id = @wi['target']['id'] rescue nil
      @job_id    = @wi['job_id']
    end
    
    def [](key)
      @wi[key]
    end
    
    def save_status(msg={})
      @wi['worker'] = {'status' => 200}.merge(msg)
    end
    
    def save_error(err)
      @wi['worker'] = {'status' => 500, 'error' => err}
    end
    
    def format_for_mq
      @wi.to_s
    #  @wi.to_json
    end
  end
    
    
  # Base class for all site-specific worker classes
  class Base
    include BackupWorker::Helper
    
    @@site = 'base'
    attr_accessor :wi
    
    def initialize(env, options={})
      log_info "Starting up worker for #{@@site}"
      load_rails_environment env
    end
    
    def run
    end
      
    def verify_database_connection!
      begin
        ActiveRecord::Base.verify_active_connections!
      rescue 
        log_error "Could not verify db connection!"
        raise
      end
    end
    
    def process_message(msg)
      log_info "Processing incoming message: #{msg.inspect}"
      run_backup_job( WorkItem.new(msg) ) do |job|
        # Start backup job & pass info in BackupSourceJob
        safely { 
          save_success_data if backup(job) 
        }
      end
    end
    
    # Yields new BackupSourceJob object based on workitem values passed
    # If object cannot be created, returns nil
    
    def run_backup_job(wi)
      @wi = wi # Save workitem object for later
      # Retrieve BackupSource record - this will be used by the child worker to 
      # determine what & how much to backup.
      job = BackupSourceJob.create(:backup_source_id => wi.source_id, :backup_job_id => wi.job_id, 
        :status => BackupStatus::Running)
      yield job
      log_debug "***DONE WITH JOB SAVING IT NOW***"
      job.finished_at = Time.now
      job.save
    end
    
    def save_success_data(msg={})
      @wi.save_status(msg)
    end
    
    def save_error(err)
      log :error, "Backup error: " + err
      @wi.save_error(err)
    end
    
    def auth_failed(source, error='Login failed')
      source.login_failed! error
      save_error error
    end
  end
  
  # Class for running message queue daemon - for production
  class QueueRunner < Base
    def run
      MQ.error("MQ error handler") do 
        log :error, "MQ error handler invoked"
        AMQP.stop { EM.stop }
        # Alert someone at this point?
      end
      
      log_info "Connecting to MQ..."
      MessageQueue.start do
        log_info "connected.  Listening on worker queue..."
        verify_database_connection!

        q = MessageQueue.backup_worker_subscriber_queue(@@site)
        q.subscribe do |msg|
          process_message(msg)
          send_results # Always send result back to publisher
        end
      end
    end
    
    def send_results
      feedback_q_name = @wi['reply_queue']
      log_info "Connecting to feedback queue: " + feedback_q_name
      MQ.queue(feedback_q_name).publish(@wi.format_for_mq)
      #log_debug "Sent response: #{@wi.format_for_mq}"
    end
  end
      
  # Class to support running from tests, command line, without using message queue EventMachine loop
  class Standalone < Base
    def run(msg)
      log_info "Running standalone process..."
      process_message(msg)
    end
    
    def send_results
     log_debug "Return workitem: #{@wi.inspect}"
    end
  end  
end
