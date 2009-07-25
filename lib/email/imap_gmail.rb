# $Id$

# Gmail email fetcher

require 'larch_extensions'
require 'forwardable'
      
module EmailGrabber
  # Gmail IMAP interface class
  # Uses Larch::IMAP for all the real work
  module IMAP
    class Gmail
      include BackupDaemonHelper
      extend Forwardable
      def_delegator :@imap, :connect, :fetch
  
      @@ExcludeMailboxes = %w( Spam Trash Drafts Receipts [Gmail]/* )
      @@ArchiveMailbox = '[Gmail]/All Mail'
      
      # opts: see larch --help (General Options)
      def initialize(user, pass, opts={})
        Larch.init :debug, @@ExcludeMailboxes
        uri           = URI('imaps://imap.gmail.com')
        uri.user      = CGI.escape user
        uri.password  = CGI.escape pass
        @imap = Larch::IMAP.new(uri, opts)
      end

      # Check if user credentials are correct for the account.
      # Any exceptions should be handled by the caller
      def authenticated?
        # Hard to check in debugger without causing deadlock
        @imap.connect
        @imap.conn 
      end
    
      def fetch_email_ids(opts={})
        opts[:since] = Larch.format_date_for_search(opts[:start_date]) if opts[:start_date]
        limit = opts[:max] || -1
        mbox = nil
        ids = []
        @imap.each_mailbox do |mailbox|
          log_info "Got mailbox #{mailbox.name}"
          if mailbox.name == @@ArchiveMailbox
            log_debug "Fetching emails from #{mailbox.name} with opts: #{opts.inspect}"

            mbox = mailbox
            ids = mailbox.fetch_ids(opts)
            break
          end
        end
        # Return mailbox object, ids array
        [mbox, ids]
      end

      private
    
      # Larch private method, copied
      def mailbox_excluded?(name)
        name = name.downcase
      
        Larch.exclude.each do |e|
          return true if (e.is_a?(Regexp) ? !!(name =~ e) : File.fnmatch?(e, name))
        end

        return false
      end
    end
  end
end