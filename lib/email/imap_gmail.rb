# $Id$

# Gmail email fetcher

require 'larch_extensions'
require 'forwardable'
      
module EmailGrabber
  # Gmail IMAP interface class
  # Uses Larch::IMAP for all the real work
  module IMAP
    class Gmail
      include BackupWorker::Helper
      extend Forwardable
      def_delegator :@imap, :connect, :fetch
  
      @@ExcludeMailboxes = %w( Spam Trash Drafts Receipts [Gmail]* )
    
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
    
      def fetch_emails(date=nil)
        opts = {}
        opts[:since] = Larch.format_date_for_search(date) if date

        ids = []
        @imap.each_mailbox do |mailbox|
          next if mailbox_excluded?(mailbox.name)
          log_debug "Checking #{mailbox.name} for emails with opts: #{opts.inspect}"

          mailbox.fetch_ids(opts).each do |id|
            yield mailbox, id if block_given?
            ids << id
          end
        end
        ids
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