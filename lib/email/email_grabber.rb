# $Id$

# Prepend this file's directory to the include path if it's not there already.
$:.unshift(File.dirname(File.expand_path(__FILE__)))
$:.uniq!

require 'imap_gmail'

module EmailGrabber  
  class << self
    # Factory class method, returns email class instance based on site
    def create(site, user, pass, opts={})
      case site.downcase.to_sym
      when :gmail
        EmailGrabber::IMAP::Gmail.new(user, pass, opts)
      end
    end
  end
end