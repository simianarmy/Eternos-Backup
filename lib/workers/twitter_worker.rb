# $Id$

# twitter backup daemon.  

require File.join(File.dirname(__FILE__), '/../twitter/twitter_activity')
require File.join(RAILS_ROOT, 'lib/twitter_backup')

module BackupWorker
  class Twitter < Base
    self.site           = 'twitter'
    self.actions        = [:tweets]
    
    attr_accessor :twitter_client
    
    # Twitter gem supports oAuth & older HTTPAuth
    def authenticate
      ::SystemTimer.timeout_after(30.seconds) do
        self.twitter_client = if backup_source.auth_token && backup_source.auth_secret
          TwitterBackup::Twitter.oauth_client(backup_source.auth_token, backup_source.auth_secret)
        else
          TwitterBackup::Twitter.http_client(backup_source.auth_login, backup_source.auth_password)
        end
        
        twitter_client.verify_credentials.id
      end
    rescue Exception => e
      save_exception "Error authenticating to Twitter", e
      false
    end
    
    protected
    
    def save_tweets
      log_info "Saving tweets"
  
      client_options = {:count => 200}
      unless as = member.activity_stream || member.create_activity_stream
        raise "Unable to get member activity stream" 
      end    
      begin
        tweets = if backup_source.needs_initial_scan
          collect_all_tweets client_options
        else
          ActivityStreamItem.cleanup_connection do
            client_options[:since_id] = as.items.twitter.newest.guid.to_i if as.items.twitter.any?
          end
          twitter_client.user_timeline client_options
        end
        # Convert tweets to TwitterActivityStreamItems and save
        tweets.flatten.map {|t| TwitterActivityStreamItem.create_from_proxy!(as.id, TwitterActivity.new(t))}
        backup_source.toggle!(:needs_initial_scan) if backup_source.needs_initial_scan
      rescue Exception => e
        save_exception "Error saving tweets", e
        return false
      end
      set_completion_counter
    end
    
    protected
    
    # Helper method to retrieve as many tweets as possible from user timeline
    # starting from beginning to end
    def collect_all_tweets(client_options)
      page = 1
      found = []
      while true
        client_options[:page] = page
        res = twitter_client.user_timeline client_options
        break unless res && res.any?
        found << res
        page += 1
      end
      found
    end
  end
end


