# $Id

# Backup Desktop App User object

require File.dirname(__FILE__) + '/facebook_activity'
require File.dirname(__FILE__) + '/facebook_query'
require File.dirname(__FILE__) + '/facebook_request'
require File.dirname(__FILE__) + '/../request_scheduler'
require 'benchmark'
require 'redis'

module FacebookBackup
  # FacebookComment
  # Helper class to store comment data with author attributes
  class FacebookComment < Hashie::Mash
    def user=(fb_user)
      self.username     = fb_user.name
      self.user_pic     = fb_user.pic_square
      self.profile_url  = fb_user.profile_url
    end

    # Returns commenter user data in hash format for external use
    def user_data
      {:username => self.username,
        :pic_url => self.user_pic,
        :profile_url => self.profile_url
      }
    end
  end
  
  # Base class for api-specific user classes
  class User    
    @@friend_post_query_group_size  = 10
    @@friend_post_query_sleep_time  = 60
    @@delayPerAPIRequest            = 1 # in seconds
    
    attr_reader :id, :profile
    
    delegate :name, :to => :user
    
    def initialize(uid)
      @id = uid
      @redis = ::BackupWorker.cache.cache
      set_api_request_delay(@@delayPerAPIRequest)
    end
  
    # Creates new FacebookBackup::Request object using scheduler based on seconds arg
    # Will overwrite any existing instance of the @request object
    def set_api_request_delay(seconds=0)
      DaemonKit.logger.debug "Setting FB api scheduler with #{seconds} sec. delay"
      scheduler = RequestScheduler::ThreadSafe.new('FacebookBackup', :delay => seconds)
      @request = FacebookBackup::Request.new(@id, scheduler)
    end
    
    def friend_names
      friends.map(&:name)
    end
    
    def friend_name(id)
      friend(id).name rescue nil
    end
      
    def group_names
      groups.map(&:name) rescue nil
    end
    
    protected 
    
    # Return next N friends to process
    def get_next_friends_batch
      # Get all friends & sort by their user IDs.
      DaemonKit.logger.debug "All friends: #{sorted_friend_ids.inspect}"
      
      # Check Redis for last friend processed
      idx = 0
      if last_friend = @redis.get(last_friend_processed_key_name)
        DaemonKit.logger.debug "Got value from Redis cache: #{last_friend}"
        # If last processed friend found, start at the next index
        if idx = sorted_friend_ids.index(last_friend.to_i)
          idx += 1
        else
          idx = 0
        end
      end
      idx = 0 if idx >= (sorted_friend_ids.size - 1)
      
      DaemonKit.logger.debug "Returning friends from index #{idx}"
      # Return at most MAX_FRIENDS_PER_POSTS_BACKUP friends - don't wrap for now
      sorted_friend_ids.slice(idx, MAX_FRIENDS_PER_POSTS_BACKUP)
    end
    
    def last_friend_processed_key_name
      "last-friend_#{id}"
    end
    
    def friends_processed_counter_key_name
      "#{id}:FB-friends-processed"
    end
  end
end