# $Id$

# 1st pass at site-specific backup daemon.  
# - Runs in EventMachine 'reactor' loop until signal caught or fatal exception.
# - Listens for workitems from Backup ruote engine, which contain, among other things:
# => user_id: Eternos Member ID
# => site_id: ID of member's facebook site record containing login auth data
# => reply_queue: name of amqp queue to send backup job status to once finished
# - When finished with backup, sends message via amqp server on reply queue, which 
# signals to the backup engine that the job's "facebook" worker is done.

# Backup methodology common to all backup daemons belongs in BackupSourceWorker::Base.

require File.join(File.dirname(__FILE__), 'backupd_worker')

module BackupWorker
  class FaceBookWorker < BackupWorker::Base    
    @@site = 'facebook'
    
    def backup(wi)
      # Simulate backup work
      sleep(2)
      wi[:worker] = {
        :bytes_backed_up => rand(100) * 1024,
        :status => 200
      }
      send_results(wi)
    end
  end
end

# Code below should go in a separate file in libexec to start the daemon

DaemonKit::Application.running! do |config|
  # Trap signals with blocks or procs
  config.trap( 'INT' ) do
    DaemonKit.logger.info 'Caught INT'
    AMQP.stop { EM.stop }
  end
  config.trap( 'TERM' ) do
    DaemonKit.logger.info 'Caught TERM'
    AMQP.stop { EM.stop }
  end
end

BackupWorker::FaceBookWorker.new('development').run
