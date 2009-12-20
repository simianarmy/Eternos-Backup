# $Id$
# Your starting point for daemon specific classes. This directory is
# already included in your load path, so no need to specify it.

require 'mq'
require 'ruote_engine'
require 'backup_helper'

class BackupDaemon
  include BackupDaemonHelper
  
  SimulationJobsPeriod = 30
  
  def initialize(env)
    load_rails_environment env

    # Need this because JSON gem causes conflicts when used with ActiveSupport::JSON
    # Not sure what the point is since the method uses ActiveSupport if it's available??
    log_debug "Available JSON backends: #{OpenWFE::Json::Backend.available.to_s}"
    #OpenWFE::Json::Backend.prefered = 'JSON'
    @fei = nil
  end
  
  # Main backup engine method - runs until signal received
  def run
    log_info "Launching AMQP event loop..."
    
    MessageQueue.start do
      log_info "connected."
      backup_q = MessageQueue.pending_backup_jobs_queue

      # Create business processing engine (Ruote)
      log_info "Creating Ruote engine..."
      # DaemonKit.logger not compatible with Logger apparently, breaks in ruote
      engine = RuoteEngine.engine :logger => Logger.new(DaemonKit.root + "/log/ruote.log")

      simulate_jobs if @options && @options[:simulate]

      log_info "Entering backup processing loop..."

      backup_q.subscribe(:ack => true) do |header, msg|
        log_debug "In backup job queue: #{header.inspect}"
        payload = YAML.load(msg)
        log_info "Got backup job: " + payload.inspect

        bu_job = BackupJob.create(:user_id => payload[:user_id])

        li = OpenWFE::LaunchItem.new(RuoteEngine::UserContentBackupProcess)
        li.job_id = bu_job.id
        li.user_id = payload[:user_id]
        li.target_sites = payload[:target_sites]        
        #li.target_sites = [{:source => 'facebook', :id => 1}]
        @fei = engine.launch(li)
        log_info "Launched backup engine ", @fei

        header.ack
      end
    end
    
    log_info "Exiting AMQP event loop."
  end # end run
  
  private
  
  def simulate_jobs
    # Simulate incoming backup jobs
    fake_jobs = MessageQueue.pending_backup_jobs_queue
    
    all_members = Member.all
    log_debug "All members: #{all_members.map(&:id)}"
    fake_jobs.publish(BackupJobMessage.new.payload(all_members.rand))
    
    EM.add_periodic_timer(SimulationJobsPeriod) {
      fake_jobs.publish(BackupJobMessage.new.payload(all_members.rand))
    }
  end

end