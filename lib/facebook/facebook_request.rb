# $Id$

require File.dirname(__FILE__) + '/../request_scheduler'

module FacebookBackup
  # Facebook-specific class using RequestScheduler for request timing
  class Request
    class FacebookNetworkError < Exception; end
    
    @@delayPerRequest = 1 # in seconds
    cattr_reader :delayPerRequest
    
    def initialize(fb_id, delay=delayPerRequest)
      @id = fb_id
      @scheduler = RequestScheduler.new('FacebookBackup', :delay => delay*1000)
    end
    
    # Helper for making network requests using the Facebooker API
    # Handles scheduling & Curl exceptions  
    def do_request
      Facebooker.timeout = 0 # Reset timeout in case it was increased from network error
      begin
        @scheduler.execute { yield }
      rescue Exception => e
        DaemonKit.logger.warn "*** facebook_request error for ID #{@id}: : #{e.class.name}: #{e.message}, #{e.backtrace}"
        raise FacebookNetworkError.new "#{e.class.name}: #{e.message}"
      end
    end
  end
end