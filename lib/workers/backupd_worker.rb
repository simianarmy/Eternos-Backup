# $Id$

require 'mq'
require 'ruote_external_workitem'
#require 'active_support/core_ext/class/inheritable_attributes'
require 'forwardable'
require 'backup_helper'
require 'system_timer'

module BackupWorker

  # Helper class for parsing ruote engine incoming workitems and 
  # formatting response sent back on amqp queue
  class WorkItem
    attr_reader :source_id, :job_id, :wi
    extend Forwardable
    def_delegator :@wi, :[]
    
    # parses ruote engine message into a RuoteExternalWorkitem
    def initialize(msg)
      @wi = RuoteExternalWorkitem.parse(msg)
      @source_id = @wi['target']['id'] rescue nil
      @job_id    = @wi['job_id']
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
    
    
  # Base class for all site-specific worker classes
  class Base
    include BackupDaemonHelper
    
    class_inheritable_accessor :site, :actions, :increment_step
    attr_accessor :wi
    
    def initialize(env, options={})
      log_info "Starting up worker for #{site}"
      load_rails_environment env
      self.increment_step = 100 / self.actions.size
    end
      
    # Parses incoming workitem & runs backup method on child class.
    # Returns WorkItem object
    def process_message(msg)
      write_thread_var :wi, wi = WorkItem.new(msg) # Save workitem object for later
      log_info "Processing incoming workitem: #{wi.to_s}"
      
      run_backup_job(wi) do |job|
        # Start backup job & pass info in BackupSourceJob
        begin
          save_success_data if backup(job) 
        rescue Exception => e
          save_error e.to_s
        end
      end
    end
    
    # Creates BackupSourceJob based on workitem values passed, yields it to caller block.
    # Saves finish time and saves it.
    def run_backup_job(wi)
      # Create or find existing BackupSourceJob record
      job = BackupSourceJob.find_or_create_by_backup_source_id_and_backup_job_id(wi.source_id, wi.job_id, 
          :status => BackupStatus::Running)
      raise "Unable to find backup source #{wi.source_id} for backup job #{wi.job_id}" unless job.backup_source
      
      yield job
  
      log_debug "***DONE WITH JOB SAVING IT NOW***"
      job.finished!
      
      thread_workitem
    end
    
    # Main work method, child classes implement core actions
    # authentication: authenticate
    # source-specific backup actions: actions
    def backup(job)
      write_thread_var :job, job
      write_thread_var :source, job.backup_source

      unless authenticate
        auth_failed 
        return false
      end
      job.status = BackupStatus::Success # successful unless an error occurs later
      
      # Run each backup callback in succession
      # Each action is responsible for calling update_completion_counter 
      actions.each { |action| send("save_#{action}") }
      
      # Returns success value
      job.status == BackupStatus::Success
      true
    end
    
    def update_completion_counter(step=increment_step)
      backup_job.increment!(:percent_complete, step) unless backup_job.percent_complete >= 100
    end
    
    def set_completion_counter(val=100)
      backup_job.update_attribute(:percent_complete, val)
    end
    
    protected
    
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
    
    def member
      backup_source.member
    end
    
    def save_success_data(msg=nil)
      workitem.save_success
      workitem.save_message(msg) if msg
    end
    
    def save_error(err)
      log :error, "Backup error: #{err}\n#{caller.join('\n')}"
      # Save error to job record if one was created 
      if j = thread_job
        j.status = "Error #{err}\nStack: #{caller.join('\n')}"
        (j.error_messages ||= []) << err
        j.save
      end
      workitem.save_error(err) # Save error in workitem
    end
    
    def auth_failed(error='Login failed')
      backup_source.login_failed! error
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
        log_info "connected."
        
        # # Uncomment this for connection keep-alive
        #         AMQP.conn.connection_status do |status|
        #           log_debug("AMQP connection status changed: #{status}")
        #           if status == :disconnected
        #             AMQP.conn.reconnect(true)
        #           end
        #         end
          
        q = MessageQueue.backup_worker_subscriber_queue(site)
        
        # Subscribe to the queue
        log_debug "Connecting to worker queue #{q.name}"
        
        q.subscribe(:ack => true) do |header, msg|
          log_debug "Received workitem."
  
          # Running worker in thread allows EM to publish messages while thread is sleeping
          # Important when worker needs to send jobs to another subscriber
          # during execution.  If not run in thread, jobs won't be published
          # unitl end of worker execution.
          # Make sure worker calls Kernel.sleep periodically in loop
          
          # Another benefit to running worker in thread is that subscriber loop can 
          # continue receiving messages, allowing daemon to run all backup jobs in 
          # parallel, which is what we want.
          Thread.new {
            # Use daemon-kit safely method to wrap blocks with exception-handling code
            # See DaemonKit::Safety for config options
            log_debug "Running worker thead..."
            safely {
              resp = process_message(msg)
              log_debug "Done processing workitem."
              send_results(resp) # Always send result back to publisher
            }
            header.ack
          }
        end
        # # Simple keep-alive ping
        #         DaemonKit::Cron.scheduler.every("5m") do
        #           MQ.queue( 'remote-participant-status' ).publish( "#{site} daemon OK" )
        #         end
      end
    end
    
    def send_results(response)
      feedback_q_name = response['reply_queue']
      MQ.queue(feedback_q_name).publish(response.to_json)
      log_debug "Published response to queue: " + feedback_q_name
    end
  end
      
  # Mixin to support running from tests, command line, without using backup_worker_subscriber_queue message queue
  module Standalone
    def run(msg)
      log_info "Running standalone process..."
      MessageQueue.start do
        q = MQ.new
        q.queue('integration_test').subscribe do |poo|
          resp = process_message(msg)
          send_results(resp)
          MessageQueue.stop
        end
        EM.add_timer(1) {
          q.queue('integration_test').publish('go')
        }
      end
    end
    
    def send_results(response)
     log_debug "Sending response to ruote amqp listener: #{response.to_json}"
    end
  end  
end
