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
    cattr_accessor :max_emails_per_backup, :emails_per_update
    @@max_emails_per_backup   = 10000
    @@emails_per_update       = 100
    
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
      
      fetch_emails
      @source.toggle!(:needs_initial_scan) if @source.needs_initial_scan
      set_completion_counter
      true
    rescue Exception => e
      save_error "Error saving emails: #{e.to_s}"
      log :error, e.backtrace
      false
    end
    
    private
    
    def fetch_emails
      max_emails_per_backup = ENV['MAX_EMAILS'].to_i if ENV['MAX_EMAILS'] 
      opts = {:max => max_emails_per_backup}
      
      if @source.backup_emails.any?
        #opts[:start_date] = @source.backup_emails.latest.first.received_at
      end
      log_debug "Fetching all emails"
      log_debug "after #{opts[:start_date]}" if opts[:start_date]
    
      @saved_emails = @source.backup_emails.map(&:message_id).inject({}) {|h, id| h[id] = 1; h}
      @mailbox, ids = @email.fetch_email_ids(opts)
      ids   -= @saved_emails.keys             # Strip already saved ids
      ids   = ids[0, max_emails_per_backup]   # Only keep max or less elements
      total = ids.count
      return unless total > 0
      
      # Iterate over emails in groups in order to track backup progress properly
      # Max 100 emails / completion counter increment
      steps             = [(total / emails_per_update), 1].max
      percent_per_step  = emails_per_update / steps
      groups            = [total, emails_per_update].min || 1
      
      log_debug "Saving #{total} emails from mailbox #{@mailbox.name} in groups of #{groups}. (#{steps} steps)"
      ids.in_groups_of(groups) do |id_group|
        id_group.each do |id|
          unless @saved_emails[id]
            begin
              process_email(id)
            rescue Exception => e
              log :error, "Exception processing email: #{e.to_s}\n#{e.backtrace}"
            end  
            @saved_emails[id] = 1
          end
        end
        # would be nice if we could flush jobs in queue so worker can start
        # processing them...seems to cache them all until amqp.stop is called.
        update_completion_counter percent_per_step
      end
    end
    
    def process_email(id)
      # Save existing email IDs into hash for fast duplicate lookup
      # How much memory for 1M emails? How long is query?
      mesg = nil
      
      log_debug "Dowloading email id: #{id}..."
      # Benchmarking can cause infinite hang during imap fetch, don't use!
      # May need to use SysTimer.timeout if I see imap hanging forever
      return unless mesg = @mailbox[id]
      
      log_debug "flags: #{mesg.flags.inspect}"
      # TODO:
      # Need to save junk message ids to disk/db for future jobs
      if (mesg.flags.include?('$Junk') || mesg.flags.include?('Junk'))
        log_debug "SKIPPING JUNK"
        return
      end

      email = BackupEmail.new(
        :backup_source  => @source, 
        :message_id     => id, 
        :mailbox        => @mailbox.name)
      email.email = mesg.rfc822
      log :warn, "Unable to save email: #{email.errors.full_messages}" unless email.save
    end
  end

  class EmailStandalone < Email
    include BackupWorker::Standalone
  end
  
  class EmailQueueRunner < Email
    include BackupWorker::QueueRunner
  end
end


