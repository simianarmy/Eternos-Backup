# Creates Ruote engine and defines participants

require 'ruote-amqp'
require 'ruote_backup'

module RuoteEngine
  class << self
    include BackupDaemonHelper
    
    def engine(options={})
      @@engine ||= init(options)
    end
  
    def init(options={})
      # starting a transient engine (no need to make it persistent?)
      # Need to specify a logger & work directory otherwise tries to create them in /
      options[:definition_in_launchitem_allowed] = true
      
      @@engine = OpenWFE::Engine.new options
      
      # For sanity-check in debugging
      @@engine.register_participant("puts_workitem") do |workitem|
        log_debug ""
        log_debug workitem.to_s
        log_debug ""
      end
      
      # Register amqp participant & listener
      @@engine.register_participant :backup, RuoteBackup::BackupParticipant
      @@engine.register_listener( RuoteAMQP::Listener, :queue => MessageQueue::Backup::FeedbackQueue)
      
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
      _timeout :after => "24h" do
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