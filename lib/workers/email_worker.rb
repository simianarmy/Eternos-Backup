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
require 'ezcrypto'

module BackupWorker
  class Email < Base
    cattr_accessor :max_emails_per_backup, :emails_per_update
    @@max_emails_per_backup   = 10000
    @@emails_per_update       = 100
    
    self.site           = 'email'
    self.actions        = [:emails]
    
    def authenticate
      begin
        write_thread_var :email, email = EmailGrabber.create(backup_source.backup_site.name, 
          backup_source.auth_login, backup_source.auth_password)
        email.authenticated?
      rescue Exception => e
        save_error "Error authenticating: #{e.to_s}"
        log :error, e.backtrace
        false
      end
    end
    
    def save_emails
      fetch_emails
      backup_source.toggle!(:needs_initial_scan) if backup_source.needs_initial_scan
      set_completion_counter
      true
    rescue Exception => e
      save_error "Error saving emails: #{e.to_s}"
      log :error, e.backtrace
      false
    end
    
    private
    
    def fetch_emails
      log_info "Fetching emails"      
      opts = {:max => max_emails_per_backup}
      
      if backup_source.backup_emails.any?
        #opts[:start_date] = backup_source.backup_emails.latest.first.received_at
      end
      log_debug "Fetching all emails"
      log_debug "after #{opts[:start_date]}" if opts[:start_date]
    
      saved_emails = backup_source.backup_emails.map(&:message_id).inject({}) {|h, id| h[id] = 1; h}
      mailbox, ids = thread_var(:email).fetch_email_ids(opts)
      write_thread_var :mailbox, mailbox
      
      ids   -= saved_emails.keys             # Strip already saved ids
      ids   = ids[0, max_emails_per_backup]   # Only keep max or less elements
      total = ids.size
      return unless total > 0
      
      # Iterate over emails in groups in order to track backup progress properly
      # Max 100 emails / completion counter increment
      steps             = [(total / emails_per_update), 1].max
      percent_per_step  = emails_per_update / steps
      groups            = [total, emails_per_update].min || 1
      
      log_debug "Saving #{total} emails from mailbox #{mailbox.name} in groups of #{groups}. (#{steps} steps)"
      ids.in_groups_of(groups) do |id_group|
        id_group.each do |id|
          unless saved_emails[id]
            begin
              process_email(id)
            rescue Exception => e
              log :error, "Exception processing email: #{e.to_s}\n#{e.backtrace}"
            end  
            saved_emails[id] = 1
            sleep(0.3) # Allow main em thread to publish messages
          end
        end
        update_completion_counter percent_per_step
      end
    end
    
    def process_email(id)
      if mesg = download_email(id)
        create_email(id, mesg) unless junk_mail? mesg
      end
    end
    
    def download_email(id)
      log_debug "Dowloading email id: #{id}..."
      mailbox = thread_var(:mailbox)
      # Infinite hang during some imap fetch workaround
      # http://ph7spot.com/articles/system_timer
      SystemTimer.timeout_after(30.seconds) { mailbox[id] }
    end
    
    def junk_mail?(mesg)
      # TODO:
      # Need to save junk message ids to disk/db for future jobs
      log_debug "flags: #{mesg.flags.inspect}"
      mesg.flags.include?('$Junk') || mesg.flags.include?('Junk')
    end
    
    def create_email(id, mesg)
      email = BackupEmail.new(
        :backup_source  => backup_source, 
        :message_id     => id, 
        :mailbox        => thread_var(:mailbox).name)
      email.email = mesg.rfc822
      unless email.save
        log :warn, "Unable to save email: #{email.errors.full_messages}"
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


