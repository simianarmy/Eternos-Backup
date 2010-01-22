# $Id$

# rss backup daemon.  

require 'feedzirra'

module BackupWorker
  class RSS < Base
    self.site           = 'rss'
    self.actions        = [:items]
    
    attr_accessor :feed
    
    def authenticate
      # Fetch feed contents from yesterday, use authentication if required
      if backup_source.auth_required?
        auth = false
        self.feed = Feedzirra::Feed.fetch_and_parse( backup_source.rss_url, 
          :http_authentication => [backup_source.auth_login, backup_source.auth_password],
          :if_modified_since => 1.day.ago,
          :on_failure => lambda { auth = false },
          :on_success => lambda { auth = true } )
        # :on_failure doesn't work that well
        auth && backup_source.valid_parse_result(feed)
      else
        true
      end
    end
    
    protected
    
    def save_items
      log_info "Saving RSS feed #{backup_source.rss_url}"
      begin
        backup_source.feed.update_from_feed(feed)
        sleep(1) unless DaemonKit.env == 'test'# Allow em to send messages to queues
      rescue Exception => e
        save_exception "Error saving feed entries", e
        return false
      end
      set_completion_counter
    end
    
    private
    
  end
end


