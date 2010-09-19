# $Id$

require 'mq'
require 'mq_recover_patch'
require 'ruote_external_workitem'
require 'forwardable'
require 'thread'
require 'backup_helper'
require 'worker_job'

module BackupWorker
  
  # Queue class
  # Initializes EM reactor & subscribes to MQ queues to listen to workitems sent 
  # by Ruote daemon.  Sends work jobs to the Worker class for processing
  #
  class Queue
    include BackupDaemonHelper

    @@consecutiveJobExecutionTime = 60 # in seconds
    
    def initialize(env, options={})
      log_info "Starting up worker daemon"
      load_rails_environment env
      # For thread safety.  Make sure all Rails classes we will use are loaded before
      # we start any threads in order to prevent const_missing errors.
      require File.join(RAILS_ROOT, 'app/models/backup_source')
      require File.join(RAILS_ROOT, 'app/models/backup_source_job') 
    end
    
    # Main daemon thread - should run until receives signal to stop
    def run
      log_info "Connecting to MQ..."
      
      MessageQueue.start do
        log_info "worker #{MQ.id} started"
        
        # Set prefetch(1) as suggested by Amman Gupta
        MQ.prefetch(20)
        EM.threadpool_size = 20 # Default: 20
        
        process_queue 
        
        # Make sure requeue timer doesn't cause BackupSourceExecutionFlood errors
        #EM.add_periodic_timer(@@consecutiveJobExecutionTime*2) { long_q.recover(:requeue => true) }

      end # MessageQueue.start
    end # run

    protected 
    
    def process_queue
      # REGULAR JOBS QUEUE
      ###############################################################
      q = MessageQueue.backup_worker_subscriber_queue('*')
      log_debug "Connecting to worker queue #{q.name}"
      jobs = 0
      
      q.subscribe(:ack => true) do |header, msg|
        unless AMQP.closing?
          # The job process
          header.ack
          unless AMQP.closing?
            # Always ack?
            log_info "Sending ACK.."
            header.ack
            unless purge_queue?
              ThreadWorker.new.run(nil, msg)
              log_debug "job #{jobs} started..."
              jobs += 1
            end
          end
        end
      end # q.subscribe
    end
    
    def purge_queue?
      File.exists? File.join(DaemonKit.root, 'tmp', PURGE_QUEUE_FILE)
    end

    def finish
      EM.forks.each {|pid| Process.kill("KILL", pid)}
      EM.stop { AMQP.stop }
    end
  end # Queue
    
  # LongQueue class
  # Inherits from Queue class & implements long-running backup worker queue
  # subscription
  #
  class LongQueue < Queue
      
    protected
    
    def process_queue
      # LONG JOBS QUEUE
      ###############################################################
      #AMQP.fork(MAX_SIMULTANEOUS_JOBS) do
        # Subscribe to really long-running jobs queue
        long_q = MessageQueue.long_backup_worker_queue
        log_debug "Connecting to worker queue #{long_q.name}"
        jobs = 0
        
        long_q.subscribe(:ack => true) do |header, msg|
          unless AMQP.closing?
            # Always ack?
            log_info "Sending ACK.."
            header.ack
            unless purge_queue?
              ThreadWorker.new.run(nil, msg)
              log_debug "long job #{jobs} started..."
            end
          end
        end # long_q.subscribe
      #end # AMQP.fork
    end
  end
  
  ### Queue Worker strategies - 
  # Used to encapsulate different EM deferral / asynch strategies
  # for easier testing
  
  # SpawnWorker class
  # Uses EM.spawn to launch deferrable worker class
  class SpawnWorker
    def run(header, msg)
      EM.spawn do
        worker = Worker.new(msg)
        # callback on set_deferred_status :succeeded inside worker
        worker.callback do |response|
          header.ack if header
        end
        worker.run
      end.notify
    end
  end
  
  # ThreadWorker class
  # Runs worker process in thread
  class ThreadWorker
    def run(header, msg)
      worker = Worker.new(msg)
      # callback on set_deferred_status :succeeded inside worker
      worker.callback do |response|
        #log_info "Sending #{q.name} ACK"
        header.ack if header
      end
      # Running worker in thread allows EM to publish messages while thread is sleeping
      # Important when worker needs to send jobs to another subscriber
      # during execution.	 If not run in thread, jobs won't be published
      # until end of worker execution.
      # Another benefit to running worker in thread is that subscriber loop can 
      # continue receiving messages, allowing daemon to run MAX_SIMULTANEOUS_JOBS in
      # parallel, which is what we want.
      Thread.new { worker.run }
    end
  end
end
