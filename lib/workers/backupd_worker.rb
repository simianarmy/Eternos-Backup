# $Id$

require 'rubygems'
require 'benchmark'
require 'custom_external_workitem'

module BackupWorker
  # Helper methods for all worker classes
  module Helper
    def load_rails_environment
      mark = Benchmark.realtime do
        require File.join(DEFAULT_RAILS_PATH, 'config', 'environment')
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
    
    def save_status(msg)
      @wi['worker'] = {'status' => 200}.merge(msg)
    end
    
    def save_error(err)
      @wi['worker'] = {'status' => 500, 'error' => err}
    end
    
    def format_for_mq
      @wi.to_json
    end
  end
    
    
  # Base class for all site-specific worker classes
  class Base
    include BackupWorker::Helper
    
    @@site = 'base'
    attr_accessor :wi
    
    def initialize(env, options={})
      log_info "Starting up worker for #{@@site}"
      load_rails_environment
    end
    
    def run
      MQ.error("MQ error handler") do 
        log :error, "MQ error handler invoked"
        AMQP.stop { EM.stop }
        # Alert someone at this point?
      end
      
      begin
        ActiveRecord::Base.verify_active_connections!
      rescue 
        log_error "Could not verify db connection!"
        raise
      end
      
      log_info "Connecting to MQ..."
      MessageQueue.start do
        log_info "connected.  Listening on worker queue..."
        
        q = MessageQueue.backup_worker_subscriber_queue(@@site)
        q.subscribe do |msg|
          create_job(WorkItem.new(msg)) do |job|
            # Start backup job & pass info in BackupSourceJob
            safely { backup(job) }
            job.save
          end
          send_results # Always send result back to publisher
        end
      end
    end
    
    # Yields new BackupSourceJob object based on workitem values passed
    # If object cannot be created, returns nil
    
    def create_job(wi)
      log_info "Processing incoming message for job #{wi.job_id}"
      @wi = wi # Save workitem object for later
      
      # Retrieve BackupSource record - this will be used by the child worker to 
      # determine what & how much to backup.
      bj = begin
        bs = BackupSource.find(wi.source_id)
        yield BackupSourceJob.create(:backup_source => bs, :backup_job_id => wi.job_id)
      rescue Exception => e
        save_error "create_job exception for job_id => #{wi.job_id}, source_id => #{wi.source_id}: #{e.to_s}"
      end
    end
    
    def send_results
      feedback_q_name = @wi['reply_queue']
      log_info "Connecting to feedback queue: " + feedback_q_name
  
      MQ.queue(feedback_q_name).publish(@wi.format_for_mq)
      log_debug "Sent response: #{@wi.to_json}"
    end
    
    def save_success_data(msg)
      @wi.save_status(msg)
    end
    
    def save_error(err)
      log :error, "Backup error: " + err
      @wi.save_error(err)
    end
  end
end
