# $Id$

require 'rubygems'
require 'benchmark'
require 'mq'
require 'custom_external_workitem' # Hoping to fix JSON crazyiness
require 'active_support/core_ext/module/attribute_accessors' # for cattr_reader
require 'active_support/core_ext/class/inheritable_attributes'

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
    attr_reader :source_id, :job_id, :wi
    
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
    
    class_inheritable_accessor :site, :actions, :increment_step
    attr_accessor :wi
    
    def initialize(env, options={})
      log_info "Starting up worker for #{site}"
      load_rails_environment env
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
    
    # Creates BackupSourceJob based on workitem values passed, yields it to caller block.
    # Saves finish time and saves it.
    def run_backup_job(wi)
      @wi = wi # Save workitem object for later
      # Retrieve BackupSource record - this will be used by the child worker to 
      # determine what & how much to backup.
      begin
        job = BackupSourceJob.create!(:backup_source_id => wi.source_id, :backup_job_id => wi.job_id, 
          :status => BackupStatus::Running)
      rescue Exception => e
        save_error "Error creating BackupSourceJob: #{e.to_s}\n#{e.backtrace}"
        return
      end
      
      yield job
      
      log_debug "***DONE WITH JOB SAVING IT NOW***"
      job.finished_at = Time.now
      job.save
    end
    
    # Main work method, child classes implement core actions
    # authentication: authenticate
    # source-specific backup actions: actions
    def backup(job)
      @job = job
      @source = job.backup_source
      
      unless authenticate
        auth_failed 
        return false
      end
      @job.status = BackupStatus::Success # successful unless an error occurs later
      
      # Run each backup callback in succession
      # Each action is responsible for calling update_completion_counter 
      actions.each { |action| send("save_#{action}") }
      
      # Returns success value
      @job.status == BackupStatus::Success
      true
    end
    
    def update_completion_counter
      @job.increment!(:percent_complete, increment_step) 
    end
    
    protected
    
    def save_success_data(msg={})
      @wi.save_status(msg)
    end
    
    def save_error(err)
      log :error, "Backup error: #{err}\n#{caller.join('\n')}"
      # Save error to job record if one was created 
      if @job
        @job.status = "Error #{err}\nStack: #{caller.join('\n')}"
        (@job.error_messages ||= []) << err
        @job.save
      end
      @wi.save_error(err) # Save error in workitem
    end
    
    def auth_failed(error='Login failed')
      @source.login_failed! error
      save_error error
    end
  end
  
  # Mixin for running message queue daemon - for production
  module QueueRunner
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

        q = MessageQueue.backup_worker_subscriber_queue(@site)
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
      
  # Mixin to support running from tests, command line, without using message queue EventMachine loop
  module Standalone
    def run(msg)
      log_info "Running standalone process..."
      process_message(msg)
    end
    
    def send_results
     log_debug "Return workitem: #{@wi.inspect}"
    end
  end  
end
