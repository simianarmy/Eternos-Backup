# $Id$

# email backup daemon.  
# - Runs in EventMachine 'reactor' loop until signal caught or fatal exception.
# - Listens for workitems from Backup ruote engine, which contain, among other things:
# => user_id: Eternos Member ID
# => site_id: ID of member's rss site record containing login auth data & RSS feed URL
# => reply_queue: name of amqp queue to send backup job status to once finished
# - When finished with backup, sends message via amqp server on reply queue, which 
# signals to the backup engine that the job's worker is done.

# Backup methodology common to all backup daemons belongs in BackupSourceWorker::Base.

require File.join(File.dirname(__FILE__), 'backupd_worker')
require File.join(File.dirname(__FILE__), '/../lib/gmail')

module BackupWorker
  class Email < Base
    self.site           = 'email'
    self.actions        = [:emails]
    self.increment_step = 100 / self.actions.size
    
    def authenticate
      begin
        @gmail = EmailGrabber::Gmail.new(@source.auth_login, @source.auth_password)
        @gmail.authenticated?
      rescue
        false
      end
    end
    
    protected
    
    def save_emails
      log_info "Saving tweets"
    
    rescue
    end
    
    private
  end
  
  class EmailStandalone < Email
    include BackupWorker::Standalone
  end
  
  class EmailQueueRunner < Email
    include BackupWorker::QueueRunner
  end
end


