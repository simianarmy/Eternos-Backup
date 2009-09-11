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

require File.join(File.dirname(__FILE__), 'backupd_worker')
require File.join(File.dirname(__FILE__), '/../twitter/twitter_activity')

module BackupWorker
  class Twitter < Base
    self.site           = 'twitter'
    self.actions        = [:tweets]
    
    def authenticate
      begin
        twitter_id = ::SystemTimer.timeout_after(30.seconds) do
          write_thread_var :client, client = ::Twitter::Base.new(
            ::Twitter::HTTPAuth.new(backup_source.auth_login, backup_source.auth_password))
          client.verify_credentials.id
        end
        log_debug "Twitter ID => #{twitter_id}"
        twitter_id && (twitter_id > 0)
      rescue Exception => e
        log :error, "Error authenticating to Twitter: #{e.to_s}"
        false
      end
    end
    
    protected
    
    def save_tweets
      require 'twitter'
      log_info "Saving tweets"
  
      client_options = {:count => 200}
      unless as = member.activity_stream || member.create_activity_stream
        raise "Unable to get member activity stream" 
      end    
      begin
        tweets = if backup_source.needs_initial_scan
          collect_all_tweets client_options
        else
          client_options[:since_id] = as.items.twitter.latest(1).first.guid.to_i if as.items.twitter.any?
          client_obj.user_timeline client_options
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
    
    private
    
    def client_obj
      thread_var :client
    end
    
    # Helper method to retrieve as many tweets as possible from user timeline
    # starting from beginning to end
    def collect_all_tweets(client_options)
      page = 1
      found = []
      while true
        client_options[:page] = page
        res = client_obj.user_timeline client_options
        break unless res && res.any?
        found << res
        page += 1
      end
      found
    end
  end
  
  class TwitterStandalone < Twitter
    include BackupWorker::Standalone
  end
  
  class TwitterQueueRunner < Twitter
    include BackupWorker::QueueRunner
  end
end


