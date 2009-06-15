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
require File.join(File.dirname(__FILE__), '../../lib/facebook/backup_user')

module BackupWorker
  class Facebook < BackupWorker::Base    
    @@site = 'facebook'
    
    def backup(job)
      # Get backup start & end dates - nil start dates indicates full backup
      source = job.backup_source
      
      # Authenticate user first
      @user = FacebookBackup::User.new(source.facebook_uid, source.facebook_session_key, source.facebook_secret_key)
      @user.login!
      return fail "Error logging into facebook for user #{@user.to_s}"
      
      # Now figure out what to backup...
      
      #if source.needs_initial_scan
        # Backup everything
      #else
        #job.source.pending_backup_dates
        # Backup only starting at some date
      #end
    end
    
    def fail(message)
      log_error message
    end
  end
end


