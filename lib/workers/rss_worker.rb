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

module BackupWorker
  class RSS < Base
    self.site           = 'rss'
    self.actions        = [:items]
    
    def authenticate
      # Fetch feed contents from yesterday, use authentication if required
      if backup_source.auth_required?
        auth = false
        write_thread_var :feed, feed = Feedzirra::Feed.fetch_and_parse( backup_source.rss_url, 
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
        backup_source.feed.update_from_feed(thread_var(:feed))
      rescue Exception => e
        save_error "Error saving feed entries: #{e.to_s}"
        log :error, e.backtrace
        return false
      end
      set_completion_counter
    end
    
    private
    
  end
  
  class RSSStandalone < RSS
    include BackupWorker::Standalone
  end
  
  class RSSQueueRunner < RSS
    include BackupWorker::QueueRunner
  end
end


