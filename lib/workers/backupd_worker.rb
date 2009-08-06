# $Id$

require 'mq'
require 'ruote_external_workitem'
#require 'active_support/core_ext/class/inheritable_attributes'
require 'forwardable'
require 'backup_helper'

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
    end
      
    def verify_database_connection!
      tries = 0
      begin
        tries += 1
        ActiveRecord::Base.verify_active_connections!
      rescue 
        unless tries > 3
          ActiveRecord::Base.connection.reconnect! 
          retry
        end
        log_error "Could not verify db connection!"
        raise
      end
    end
    
    # Parses incoming workitem & runs backup method on child class.
    # Returns WorkItem object
    def process_message(msg)
      log_info "Processing incoming message: #{msg.inspect}"
      verify_database_connection!
      
      run_backup_job( WorkItem.new(msg) ) do |job|
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
      @wi = wi # Save workitem object for later
      # Retrieve BackupSource record - this will be used by the child worker to 
      # determine what & how much to backup.
      job = BackupSourceJob.create!(:backup_source_id => wi.source_id, :backup_job_id => wi.job_id, 
          :status => BackupStatus::Running)
      
      yield job
      
      log_debug "***DONE WITH JOB SAVING IT NOW***"
      job.finished_at = Time.now
      job.save
      @wi
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
    
    def update_completion_counter(step=increment_step)
      @job.increment!(:percent_complete, step) 
    end
    
    def set_completion_counter(val=100)
      @job.update_attribute(:percent_complete, val)
    end
    
    protected
    
    def save_success_data(msg=nil)
      @wi.save_success
      @wi.save_message(msg) if msg
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
        log_info "connected."
        verify_database_connection!
        
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
        #q.subscribe do |header, msg|
          log_debug "Received workitem: #{msg.inspect}"
          
          safely {
            resp = process_message(msg)
            log_debug "Done processing workitem"
            send_results(resp) # Always send result back to publisher
          }    
          header.ack
        end
        # # Simple keep-alive ping
        #         DaemonKit::Cron.scheduler.every("5m") do
        #           MQ.queue( 'remote-participant-status' ).publish( "#{site} daemon OK" )
        #         end
      end
    end
    
    def send_results(response)
      feedback_q_name = response['reply_queue']
      log_info "Connecting to feedback queue: " + feedback_q_name
      MQ.queue(feedback_q_name).publish(response.to_json)
      log_debug "Sent response to ruote amqp listener: #{response.to_json}"
    end
  end
      
  # Mixin to support running from tests, command line, without using message queue EventMachine loop
  module Standalone
    def run(msg)
      log_info "Running standalone process..."
      MessageQueue.start do
        q = MQ.new
        q.prefetch(1)
        q.queue('integration_test').subscribe(:ack => true) do |headers, shit|
          resp = process_message(msg)
          send_results(resp)
          headers.ack
          MessageQueue.stop
        end
        q.queue('integration_test').publish('go')
      end
    end
    
    def send_results(response)
     log_debug "Sending response to ruote amqp listener: #{response.to_json}"
    end
  end  
end
