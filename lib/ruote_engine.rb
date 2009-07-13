# Creates Ruote engine and defines participants

require 'openwfe/engine' # sudo gem install ruote
require 'openwfe/extras/participants/amqp_participants'
require 'openwfe/extras/listeners/amqp_listeners'
require 'ruote_backup'
 
module RuoteEngine
  class << self
    include BackupDaemonHelper
    
    def engine(options={})
      @@engine ||= init(options)
    end
  
    def init(options={})
      # starting a transient engine (no need to make it persistent?)
      @@engine = OpenWFE::Engine.new(:definition_in_launchitem_allowed => true)
      
      # For sanity-check in debugging
      @@engine.register_participant("puts_workitem") do |workitem|
        log_debug ""
        log_debug workitem.to_s
        log_debug ""
      end
      
      # This participant dispatches its workitem to an Amazon SQS queue
      # If the queue doesn't exist, the participant will create it.
      #@@engine.register_participant(:sqs_fb, SqsParticipant.new("workqueue0"))
      
      # Register amqp participant & listener
      @@engine.register_participant :backup, RuoteBackup::BackupParticipant
      @@engine.register_listener(OpenWFE::Extras::AMQPListener, :queue => MessageQueue::Backup::FeedbackQueue)
      
      # Participant that processes results once all backup jobs have finished
      @@engine.register_participant :save_results, RuoteBackup::SaveResultsParticipant
      
      @@engine
    end
  end
  
  # A processes that starts and tracks the backup process of user
  # content: social network, email, ...
  # Keeps track of backup state in database upon completion and on error.

  class UserContentBackupProcess < OpenWFE::ProcessDefinition
    # required fields in the launchitem
    param :field => "job_id"
    param :field => "user_id"
    param :field => "target_sites"
    
    sequence do  
      _timeout :after => "10m" do
        concurrent_iterator :on_field_value => "target_sites", :to_field => "target", 'merge-type' => 'isolate' do
          sequence do
            backup
          end
        end
      end
      save_results
    end
  end
end