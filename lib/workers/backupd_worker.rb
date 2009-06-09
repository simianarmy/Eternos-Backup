# $Id$

require 'rubygems'
require 'ruote_external_workitem'
require 'benchmark'
require File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment')

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
      puts args
    end
  end
  
  # Base class for all site-specific worker classes
  class Base
    include BackupWorker::Helper
    
    @@site = 'base'
    
    def initialize(env, options={})
      log_info "Starting up worker for #{@@site}"
      load_rails_environment
    end
    
    def run
      log_info "Connecting to MQ..."

      MessageQueue.start do
        log_info "connected.  Listening on worker queue..."
        
        q = MessageQueue.backup_worker_subscriber_queue(@@site)
        q.subscribe do |msg|
          process_message(RuoteExternalWorkitem.parse(msg))
        end
      end
    end
    
    def process_message(wi)
      log_info "Processing incoming message: #{wi.attributes.inspect}"
      
      @source = wi['target']['source']
      
      backup(wi) # Call child class method
    end
    
    def send_results(wi)
      feedback_q_name = wi['reply_queue']
      log_info "Connecting to feedback queue: " + feedback_q_name
      
      feedback_q = MQ.queue(feedback_q_name)
      feedback_q.publish(wi.to_json)
    end
  end
end
