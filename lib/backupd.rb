# $Id$
# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.

require 'rubygems'
require 'openwfe/engine' # sudo gem install ruote
require 'openwfe/extras/participants/amqp_participants'
require 'openwfe/extras/listeners/amqp_listeners'
require 'ruote_engine'
require 'mq'
require 'backup_helper'
# DO NOT require 'json' or variants!  Breaks when used with active_support!
#require 'json/add/rails'

class BackupDaemon
  include BackupDaemonHelper
  
  def initialize(env)
    load_rails_environment
    # Need this because JSON gem causes conflicts when used with ActiveSupport::JSON
    OpenWFE::Json::Backend.prefered = 'ActiveSupport'
  end
  
  # Main backup engine method - runs until signal received
  def run
    # Run within EventMachine block ... amqp driver requires it
    log_info "Launching"
    log_info "Connecting to MQ..."
    
    MessageQueue.start do
      log_info "connected."
      fake_jobs = MessageQueue.pending_backup_jobs_queue
      backup_q = MessageQueue.pending_backup_jobs_queue
        # Create queue & bind it to the exchange, listen for backup messages
        #q = mq.create_queue 'backup_job_q', :durable => true
        #pub_q = mq.create_queue 'backup_work_q', :durable => true

      # Create business processing engine (Ruote)
      log_info "Creating Ruote engine..."
      engine = RuoteEngine.engine

      # Simulate incoming backup jobs
      all_members = Member.all
      fake_jobs.publish(BackupJobMessage.new.payload(all_members.rand))
      EM.add_periodic_timer(10) {
         fake_jobs.publish(BackupJobMessage.new.payload(all_members.rand))
      }
      log_info "Entering backup processing loop..."
      backup_q.subscribe do |msg|
        payload = YAML.load(msg)
        log_info "Got backup job: " + payload.inspect
        bu_job = BackupJob.create(:user_id => payload[:user_id])
        
        li = OpenWFE::LaunchItem.new(RuoteEngine::UserContentBackupProcess)
        li.job_id = bu_job.id
        li.user_id = payload[:user_id]
        #li.target_sites = payload[:target_sites]        
        li.target_sites = [{:source => 'facebook', :id => 1}, {:source => 'twitter', :id => 2}]
        fei = engine.launch(li)
      end
    end
  end # end run
end