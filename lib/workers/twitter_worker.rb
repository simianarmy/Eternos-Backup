# $Id$

# twitter backup daemon.  
# - Runs in EventMachine 'reactor' loop until signal caught or fatal exception.
# - Listens for workitems from Backup ruote engine, which contain, among other things:
# => user_id: Eternos Member ID
# => site_id: ID of member's rss site record containing login auth data & RSS feed URL
# => reply_queue: name of amqp queue to send backup job status to once finished
# - When finished with backup, sends message via amqp server on reply queue, which 
# signals to the backup engine that the job's worker is done.

# Backup methodology common to all backup daemons belongs in BackupSourceWorker::Base.

require File.join(File.dirname(__FILE__), '/../twitter/twitter_activity')
#require File.join(RAILS_ROOT, 'vendor', 'gems', 'twitter-0.6.15', 'lib', 'twitter')
require File.join(RAILS_ROOT, 'lib/twitter_backup')

module BackupWorker
  class Twitter < Base
    self.site           = 'twitter'
    self.actions        = [:tweets]
    
    attr_accessor :twitter_client
    
    # Twitter gem supports oAuth & older HTTPAuth
    def authenticate
      ::SystemTimer.timeout_after(30.seconds) do
        twitter_client = if backup_source.auth_token && backup_source.auth_secret
          TwitterBackup::Twitter.oauth_client(backup_source.auth_token, backup_source.auth_secret)
        else
          TwitterBackup::Twitter.http_client(backup_source.auth_login, backup_source.auth_password)
        end
        
        twitter_client.verify_credentials.id
      end
    rescue Exception => e
      log :error, "Error authenticating to Twitter: #{e.to_s}"
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
        as.items << tweets.flatten.map {|t| TwitterActivityStreamItem.create_from_proxy(TwitterActivity.new(t))}
        backup_source.toggle!(:needs_initial_scan) if backup_source.needs_initial_scan
      rescue Exception => e
        save_error "Error saving tweets: #{e.to_s}"
        log :error, e.backtrace
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


