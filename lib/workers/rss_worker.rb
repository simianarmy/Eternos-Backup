# $Id$

# rss backup daemon.  
# - Runs in EventMachine 'reactor' loop until signal caught or fatal exception.
# - Listens for workitems from Backup ruote engine, which contain, among other things:
# => user_id: Eternos Member ID
# => site_id: ID of member's rss site record containing login auth data & RSS feed URL
# => reply_queue: name of amqp queue to send backup job status to once finished
# - When finished with backup, sends message via amqp server on reply queue, which 
# signals to the backup engine that the job's worker is done.

# Backup methodology common to all backup daemons belongs in BackupSourceWorker::Base.

require File.join(File.dirname(__FILE__), 'backupd_worker')
require 'feedzirra'
require 'active_support/core_ext/module/attribute_accessors' # for mattr_reader


module BackupWorker
  module RSS
    mattr_reader :site, :actions, :increment_step
    @@site = 'blog'
    @@actions = [:items]
    @@increment_step = 100 / self.actions.size
    
    def authenticate
      # Fetch feed contents from yesterday, use authentication if required
      if !@source.auth_login.blank? || !@source.auth_password.blank?
        @feed = Feedzirra::Feed.fetch_and_parse( @source.rss_url, 
          :http_authentication => [@source.auth_login, @source.auth_password],
          :if_modified_since => 1.day.ago,
          :on_failure => lambda { @auth = false },
          :on_suceess => lambda { @auth = true } )
      else
        @feed = Feedzirra::Feed.fetch_and_parse( @source.rss_url, 
          :if_modified_since => 1.day.ago,
          :on_failure => lambda { @auth = false },
          :on_suceess => lambda { @auth = true } )
      end
    end
    
    protected
    
    def save_items
      log_info "Saving RSS feed #{@source.rss_url}"
      begin
        FeedEntry.add_entries(@source.id, @feed.entries)
        true
      rescue Exception => e
        save_error "Error saving feed entries: #{e.to_s}"
        log :error, e.backtrace
        false
      end
    end
  end
  
  class RSSStandalone < RSS
    include BackupWorker::Standalone
  end
  
  class RSSQueueRunner < RSS
    include BackupWorker::QueueRunner
  end
end


