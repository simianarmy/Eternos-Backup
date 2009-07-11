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
require 'twitter'

module BackupWorker
  class Twitter < Base
    self.site           = 'twitter'
    self.actions        = [:tweets]
    self.increment_step = 100 / self.actions.size
    
    def authenticate
      begin
        @client = ::Twitter::Base.new(::Twitter::HTTPAuth.new(@source.auth_login, @source.auth_password))
        response = @client.verify_credentials
        response && response.id > 0
      rescue
        false
      end
    end
    
    protected
    
    def save_tweets
      log_info "Saving tweets"
      client_options = {:count => 200}
      stream = @source.member.activity_stream
      
      begin
        tweets = if @source.needs_initial_scan
          collect_all_tweets client_options
        else
          client_options[:since_id] = stream.items.twitter.latest.first.guid.to_i if stream.items.twitter.any?
          @client.user_timeline client_options
        end
        # Convert tweets to TwitterActivityStreamItems and save
        stream.items << tweets.map {|t| TwitterActivityStreamItem.create_from_proxy(TwitterActivity.new(t))}
        @source.toggle!(:needs_initial_scan) if @source.needs_initial_scan
      rescue Exception => e
        save_error "Error saving tweets: #{e.to_s}"
        log :error, e.backtrace
        return false
      end
      update_completion_counter
    end
    
    private
    
    # Helper method to retrieve as many tweets as possible from user timeline
    # starting from beginning to end
    def collect_all_tweets(client_options)
      page = 1
      found = []
      while true
        client_options[:page] = page
        res = @client.user_timeline client_options
        break unless res && res.any?
        found += res
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


