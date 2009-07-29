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
    @@MaxEmailsPerBackup  = 10000
    
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
      opts = {:max => @@MaxEmailsPerBackup}
      if @source.backup_emails.any?
        #opts[:start_date] = @source.backup_emails.latest.first.received_at
      end
      log_debug "Fetching all emails"
      log_debug "after #{opts[:start_date]}" if opts[:start_date]
    
      @saved_emails = @source.backup_emails.map(&:message_id).inject({}) {|h, id| h[id] = 1; h}
      @mailbox, ids = @email.fetch_email_ids(opts)
      ids -= @saved_emails.keys # Strip already saved ids
      
      # Iterate over emails in groups in order to track backup progress properly
      total     = [ids.count, @@MaxEmailsPerBackup].min
      steps     = [total / 100, 1].max
      percent_per_step = 100 / steps
      
      log_debug "Saving #{total} emails from mailbox #{@mailbox.name}.  steps = #{steps}"
      ids.in_groups_of(steps) do |id_group|
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
        update_completion_counter percent_per_step
      end
    end
    
    def process_email(id)
      # Save existing email IDs into hash for fast duplicate lookup
      # How much memory for 1M emails? How long is query?
      mesg = nil
      
      log_debug "Dowloading email id: #{id}..."
      # Benchmarking can cause infinite hang during imap fetch, don't use!
      #mark = Benchmark.realtime do
        mesg = @mailbox.fetch(id)
      #end
      log_debug "downloaded in #{mark} seconds"
      return unless mesg
            
      log_debug "flags: #{mesg.flags.inspect}"
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


