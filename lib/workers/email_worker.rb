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
require File.join(File.dirname(__FILE__), '/../email/email_grabber')

module BackupWorker
  class Email < Base
    self.site           = 'email'
    self.actions        = [:emails]
    self.increment_step = 100 / self.actions.size
    
    def authenticate
      begin
        @email = EmailGrabber.create(@source.backup_site.name, @source.auth_login, @source.auth_password)
        @email.authenticated?
      rescue Exception => e
        save_error "Error authenticating: #{e.to_s}"
        log :error, e.backtrace
        false
      end
    end
    
    def save_emails
      log_info "Saving emails"
      
      if @source.needs_initial_scan || @source.backup_emails.empty?
        fetch_all
        @source.toggle!(:needs_initial_scan)
      else
        fetch_recent
      end
      update_completion_counter
      true
    rescue Exception => e
      save_error "Error saving emails: #{e.to_s}"
      log :error, e.backtrace
      false
    end
    
    private
    
    def fetch_all
      log_debug "Fetching all emails"
      @saved_emails = {}
      @email.fetch_all do |mailbox, id|
        process_email(mailbox, id) unless @saved_emails[id]
      end
    end
    
    def fetch_recent
      start_date = @source.backup_emails.latest.first.received_at - 1
      log_debug "Fetching all emails after #{start_date}"      
    
      @saved_emails = @source.backup_emails.map(&:message_id).inject({}) {|h, id| h[id] = 1; h}
      @email.fetch_recent(start_date) do |mailbox, id|
        process_email(mailbox, id) unless @saved_emails[id]
      end
    end
    
    def process_email(mailbox, id)
      # Save existing email IDs into hash for fast duplicate lookup
      # How much memory for 1M emails? How long is query?
      log_debug "Saving email from mailbox: #{mailbox.name} id: #{id}"
      if mesg = mailbox[id]
        unless BackupEmail.create(:backup_source => @source, :message_id => id, :email => mesg.rfc822)
          log :warn, "Unable to save email: #{email.errors.full_messages}"
        end
        @saved_emails[id] = 1
      end
    end
  end

  class EmailStandalone < Email
    include BackupWorker::Standalone
  end
  
  class EmailQueueRunner < Email
    include BackupWorker::QueueRunner
  end
end


