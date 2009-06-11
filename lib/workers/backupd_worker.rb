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
  
  # Base class for all site-specific worker classes
  class Base
    include BackupWorker::Helper
    
    @@site = 'base'
    
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
      
      log_info "Connecting to MQ..."
      
      MessageQueue.start do
        log_info "connected.  Listening on worker queue..."
        
        q = MessageQueue.backup_worker_subscriber_queue(@@site)
        q.subscribe do |msg|
          process_message(RuoteExternalWorkitem.parse(msg))
          send_results
        end
      end
    end
    
    def process_message(wi)
      log_info "Processing incoming message: #{wi.attributes.inspect}"
      
      @wi = wi

      # Run in safely block to notify us of any exceptions
      begin
        source_id = @wi['target']['id'].to_i
        @backup_source = BackupSource.find(source_id)
      rescue
        log :error, "process_message: Unable to find BackupSource with id => #{source_id}"
        save_error "Invalid BackupSource id: #{source_id}"
        return
      end
      safely do
        backup(@backup_source)
      end
    end
    
    def send_results
      feedback_q_name = @wi['reply_queue']
      log_info "Connecting to feedback queue: " + feedback_q_name
  
      MQ.queue(feedback_q_name).publish(@wi.to_json)
      log_debug "Sent response: #{@wi.to_json}"
    end
    
    def save_success_data(msg={})
      @wi['worker'] = {'status' => 200}.merge(msg)
    end
    
    def save_error(err)
      @wi['worker'] = {'status' => 500, 'error' => err}
    end
  end
end
