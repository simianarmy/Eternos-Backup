# $Id$

# Gmail email fetcher
# Prepend this file's directory to the include path if it's not there already.
$:.unshift(File.dirname(File.expand_path(__FILE__)))
$:.uniq!

require 'larch_extensions'
require 'forwardable'
      
module EmailGrabber
  # Gmail IMAP interface class
  # Uses Larch::IMAP for all the real work
  class Gmail
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
    
    def fetch_all
      @imap.each_mailbox do |mailbox|
        next if mailbox_excluded?(mailbox.name)
        log :debug, "#{mailbox.name}: " << mailbox.length.to_s
        mailbox.each do |id|
          yield mailbox, id if block_given?
          id
        end
      end
    end
    
    def fetch_recent(date)
      imap_date = Larch.format_date_for_search(date)
      ids = []
      @imap.each_mailbox do |mailbox|
        next if mailbox_excluded?(mailbox.name)
        log :debug, "Checking #{mailbox.name} for emails newer than #{imap_date}..."
        
        mailbox.recent(imap_date).each do |id|
          log :debug, "found email #{id}"
          
          yield mailbox, id if block_given?
          ids << id
        end
      end
      ids
    end
    
    private
    
    def log(level, message)
      puts message
    end
    
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