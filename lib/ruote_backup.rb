# $Id$

# BackupParticipant
# Base class for all backup participant classes
# 
# A participant is the main workhorse of the Ruote engine
# The goal of the process engine is to orchestrate work among participants. 
# This is done by sending and receiving workitems, asynchronously, from those participants.

require 'backup_helper'

module RuoteBackup
  
  # Custom AMQPParticipant that forwards workitems to AMQP topic exchange
  # Base class only supports direct exchange
  
  class BackupParticipant < RuoteAMQP::Participant
    include BackupDaemonHelper
  
    # this is the method called when the participant expression hands a workitem
    # to this participant
    #
    def initialize(options={})
      log_debug "Initializing backup participant: #{self.class.to_s}"
      super(options)
    end
  
    # override base class method to use MQ topic exchange instead of direct exchange
    def consume(workitem)
      log_debug "consuming workitem #{workitem.to_s}"
      
      bu_info = workitem.attributes['target']
      enc_wi = encode_workitem(workitem)
      
      # Send backup job message to mq 
      if bu_info.has_key? :source
        # Route message to target backup queue based on data type
        source = bu_info[:source]
        case bu_info[:options][:dataType]
        when EternosBackup::SiteData::General
          log_info "sending backup job message to mq topic exchange for key => #{MessageQueue.backup_worker_topic_route(source)}..."
          MessageQueue.backup_worker_topic.publish(enc_wi, 
            :key => MessageQueue.backup_worker_topic_route(source))
        
        else EternosBackup::SiteData::FacebookOtherWallPosts
          log_info "sending backup job message to long running backup queue"
          MessageQueue.long_backup_worker_queue.publish(enc_wi)
        end
        
        # Sanity check to make sure publish worked
        log_info "sent."
      else
        log_error "Backup source not specified in workitem!"
      end
    end
  
    def cancel(workitem)
      DaemonKit.logger.warn "#{self.class.to_s} CANCELED"
      workitem.attributes['canceled'] = 1
    end
    
    protected 
  
    # Override base class method to avoid json fuckiness
    def encode_workitem(wi)
      wi.attributes['reply_queue'] = RuoteAMQP::Listener.queue
      wi.to_h.to_json # pray that listener can decode without croaking 
    end
    
    def feedback_queue_name(workitem)
      "#{workitem.flow_expression_id.workflow_instance_id}.#{workitem.flow_expression_id.expression_name}"
    end
  
    # NOTE: Not used - replaced by AMQPListener class.
    # Keeping as example of a direct queue consumer
    
    def listen_for_reply(queue)
      #wait for response on queue whose name we generated
      #    only we can consume messages from this queue
      xchange = MQ.direct("backup_feedback")
      feedback_q = MQ.queue(queue, :exclusive => true, :auto_delete => true).bind(xchange)
      feedback_q.subscribe { |msg| 
        feedback = RuoteExternalWorkitem.parse(msg)
        reply_to_engine(feedback) # let flow resume
        feedback_q.unsubscribe
      }
    end
  end
  
  # Participant responsible for reading the results of all backups of one job and 
  # updating db tables with data
  
  class SaveResultsParticipant
    include BackupDaemonHelper
    
    def initialize(*args)
      log_debug "Initializing participant: #{self.class.to_s}"
    end
    
    def consume(workitem)
      log_info "Finished backup job - saving results to db"      
      log_debug "workitem: #{workitem.to_s}"
      info = {:errors => [], :messages => [], :total_bytes => 0, :status => 'ok', :cancel => false}
      
      # If a timeout forced the job to terminate - the status won't be in the workitem
      if workitem.attributes.has_key? 'job_id'
        # Timed out - no feedback info available
        info[:errors] << "Timed out"
        info[:status] = 'fail'
        info[:cancel] = true
        info[:job_id] = workitem.attributes['job_id']
        info[:user_id] = workitem.attributes['user_id']
      else
        # Collect each backup workers' feedback if concurrent jobs all responded.
        # Each worker workitem is collected with a 'numeric' string key
        workitem.attributes.each do |key, item|
          next unless item.has_key? 'worker'
          worker = item['worker']
          log_debug "workitem attributes #{key} => #{item.inspect}"
          
          info[:status] = 'failed' unless worker['status'] == 200
          info[:messages] << worker['message'] if worker['message']
          info[:errors] << worker['error'] if worker['error']
          info[:total_bytes] += worker['bytes_backed_up'] if worker['bytes_backed_up']
          info[:job_id] ||= item['job_id'] # Not in main attributes so must use this
          info[:user_id] ||= item['user_id']
        end
      end
      info[:errors] = "No job id from backup workers" unless info[:job_id]
      log_info "Job info: #{info.inspect}"
      
      begin
        raise "No job id" unless info[:job_id]
        
        BackupJob.find(info[:job_id]).finish! info
      rescue Exception => e
        DaemonKit.logger.error "Error saving backup status to db: #{e.to_s}"
      end
    end
  end
end
