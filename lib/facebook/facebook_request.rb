# $Id$

module FacebookBackup
  # Facebook-specific class using RequestScheduler for request timing
  class Request
    class FacebookNetworkError < Exception; end
    
    def initialize(fb_id, scheduler)
      @id = fb_id
      @scheduler = scheduler
    end
    
    # Helper for making network requests using the Facebooker API
    # Handles scheduling & Curl exceptions  
    def do_request
      Facebooker.timeout = 0 # Reset timeout in case it was increased from network error
      begin
        @scheduler.execute { yield }
      rescue Facebooker::Session::UnknownError, NoMethodError => e
        DaemonKit.logger.warn "*** Facebooker fail: #{e.message}"
      rescue Curl::Err::HostResolutionError, Curl::Err::GotNothingError => e
        DaemonKit.logger.warn "*** facebook_request net error for ID #{@id}: : #{e.class.name}: #{e.message}"
      rescue Exception => e
        DaemonKit.logger.warn "*** facebook_request error for ID #{@id}: : #{e.class.name}: #{e.message}, #{e.backtrace}"
        raise FacebookNetworkError.new "#{e.class.name}: #{e.message}"
      end
    end
    
    # Checks if exception object is one that merits another attempt at a request
    def retry_from_error?(e)
      e.class == Facebooker::Session::UnknownError ||
      e.message =~ /could not be completed due to resource limits/
    end
  end
end