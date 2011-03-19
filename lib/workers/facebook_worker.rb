
# $Id$

# 1st pass at site-specific backup daemon.  
# - Runs in EventMachine 'reactor' loop until signal caught or fatal exception.
# - Listens for workitems from Backup ruote engine, which contain, among other things:
# => user_id: Eternos Member ID
# => site_id: ID of member's facebook site record containing login auth data
# => reply_queue: name of amqp queue to send backup job status to once finished
# - When finished with backup, sends message via amqp server on reply queue, which 
# signals to the backup engine that the job's "facebook" worker is done.

# Backup methodology common to all backup daemons belongs in BackupSourceWorker::Base.

require File.join(File.dirname(__FILE__), '../facebook/init') 

module BackupWorker
  class Facebook < Base
    
    self.site = 'facebook'
    self.actions = {
     EternosBackup::SiteData.defaultDataSet => [
       :profile, :friends, :photos, :posts, :administered_pages, :messages
      ],
     #EternosBackup::SiteData::FaceboookWallPosts => [:posts],
     EternosBackup::SiteData::FacebookOtherWallPosts => [:posts_to_friends]
    }
    
    attr_accessor :fb_user
    
    def authenticate
      unless backup_source.auth_secret
        save_error 'Cannot login to Facebook: no secret key'
        return false
      end
      # If auth_token key exists, we are using the legacy REST API
      if backup_source.auth_token
        self.fb_user = FacebookBackup::Rest::User.new(backup_source.auth_login, 
          backup_source.auth_token, backup_source.auth_secret)
      else
        self.fb_user = FacebookBackup::OpenGraph::User.new(backup_source.auth_login, 
          backup_source.auth_secret, :vault)
      end
      
      log_debug "Logging in Facebook user => #{fb_user.inspect}"
      fb_user.login!
      
      if fb_user.logged_in?
        backup_source.logged_in!
        true
      else 
        false
      end
    end
    
    protected
    
    def save_profile(options)
      log_info "saving profile"

      #   Save with versioning
      # TODO: Use FB's new real-time update notifications
      data = fb_user.profile
      member.profile.update_attribute(:facebook_data, data) if valid_profile(data)     
      #facebook_profile.sync_data(data) if valid_profile(data)
     
      update_completion_counter
      true
    rescue Exception => e
      save_exception "Error saving profile data", e
      false
    end
    
    def save_friends(options)
      log_info "saving friends and groups"
      
      if friends = fb_user.friend_names
        facebook_content.update_attribute(:friends, friends.sort)
      end
      if groups = fb_user.group_names
        facebook_content.update_attribute(:groups, groups.sort)
      end
      #sleep(ConsecutiveRequestDelaySeconds * 2)
      
      update_completion_counter
      true
    rescue Exception => e
      save_exception "Error fetching facebook friends list", e
      false
    end

    # Just collect the page info of the pages user administers
    def save_administered_pages(options)
      log_info "saving pages"
      
      unless as = member.activity_stream || member.create_activity_stream
        raise "Unable to get member activity stream" 
      end
      
      if pages = fb_user.administered_pages
        # Save page info and association with user
        backup_source.save_administered_pages(pages)
        
        # Save page stream activity owned by user
        pages.each do |page|
          log_debug "Getting posts on page #{page.name}"
          if posts = fb_user.get_page_posts(page.page_id)
            #log_debug "PAGE POSTS: #{posts.inspect}"
            sync_posts as, posts
          end
          # TODO: Get everything!
          # tagged, links, photos, groups, albums, statuses, videos, notes, events, checkins!!
        end
      end
      
      update_completion_counter
      true
    rescue Exception => e
      save_exception "Error fetching facebook pages list", e
      false
    end
    
    def save_photos(options)
      log_info "Fetching photos"

      fb_user.albums.each do |album|
        # If album is already backed up, check for modifications
        DaemonKit.logger.debug "Album ID: #{album.id}"
        if fba = backup_source.photo_album(album.id)
          # Save latest changes
          if fba.modified?(album) || fba.needs_metadata_synch?
            log_debug "Updating photo album: #{fba.to_s}"
            fba.save_album(album, fb_user.photos(album, :with_tags => true))
          end
        else # otherwise create it
          log_debug "Importing photo album #{album.inspect}"
          new_album = BackupPhotoAlbum.import(backup_source, album)
          new_album.save_photos(fb_user.photos(album, :with_tags => true))
        end
      end
      
      update_completion_counter
      true
    rescue Exception => e
      save_exception "Error saving photos", e
      false
    end

    # Saves facebook messages, using similar logic as save_photos
    def save_messages(options)
      log_info "Fetching messages"

      fb_user.threads.each do |t|
        # If thread is already backed up, check for modifications
        if fb_thread = backup_source.message_threads.find(:first, :conditions => 
          ['folder_id = ? AND message_thread_id = ?', t.folder_id, t.id])
          # Save latest changes
          if fb_thread.modified?(t)
            log_info "Updating thread: #{fb_thread.id}"
            # Retrieve messages and sync
            fb_thread.sync_thread(fb_user.messages(t))
          else
            log_debug "thread not modified"
          end
        else # otherwise save
          log_info "Saving new thread: #{t.id}"
          # Retrieve messages and sync
          backup_source.message_threads.save_thread!(backup_source.id, fb_user.messages(t))
        end
      end
      
      update_completion_counter
      true
    rescue Exception => e
      save_exception "Error saving messages", e
      false
    end
    
    # Save status updates and comments
    def save_posts(options)
      log_info "save_posts with options #{options.inspect}"

      unless as = member.activity_stream || member.create_activity_stream
        raise "Unable to get member activity stream" 
      end
      
      # ActivityStreamItem.cleanup_connection do
      #         if item = as.items.facebook.newest
      #           # Don't limit to last item's date otherwise we'll miss new comments on older posts...
      #           # We may want to use 2 or 3 days back from more recent
      #           #options[:start_at] = item.published_at.to_i
      #           log_debug "starting at #{options[:start_at]}"
      #         end
      #       end      
      if posts = fb_user.get_posts(options)
        sync_posts as, posts
      end
      
      if comments = fb_user.get_post_comments(options)
        sync_posts as, comments
      end
      
      update_completion_counter
      true
    rescue Exception => e
      save_exception "Error fetching facebook wall posts", e
      false
    end

    # Save posts on other walls
    # This could take a long time if user has > 100 friends so we don't want to 
    # do this at the same frequency as the other general backup
    def save_posts_to_friends(options={})
      log_info "save_posts_to_friends with options #{options.inspect}"
      
      unless as = member.activity_stream || member.create_activity_stream
        raise "Unable to get member activity stream" 
      end
      
      # Use our own api request delay algorithm, so tell the fb_user object
      # to use a no-delay scheduler
      fb_user.set_api_request_delay(0)
      
      begin
        @finished = fb_user.get_posts_to_friends(options) do |posts|
          log_info "Writing friend wall posts to db.."
          sync_posts as, posts
        end
      rescue Exception => e
        save_exception "Error fetching facebook friends' wall posts", e
        return false
      end

      # If there are more friends to process, raise error to requeue job
      # ALWAYS RETURN TRUE NOW - NEXT JOB WILL START AT NEXT FRIEND
      if true || @finished
        update_completion_counter
        true
      else
        raise BackupIncomplete, "save_posts_to_friends: Member #{member.id} has more friends to process"
      end
    end
    
    protected
      
    def valid_profile(data) 
      data && data.any? 
    end
      
    # DEPRECATED: use facebook_profile
    def facebook_content 
      member.profile.facebook_content || member.profile.build_facebook_content 
    end
    
    def facebook_profile
      backup_source.facebook_profile || backup_source.build_facebook_profile
    end
    
    # Generates unique cache index key from activity stream item & post object
    def activity_stream_item_key(stream, post)
      [stream.id, post.created.to_i, post.id].join('-')
    end
    
    # Fetches saved stream item.  Returns nil if not found
    def lookup_activity_stream_item(stream, post)
      @item = nil
      
      # Use Redis cache to speed up basic select
      cache_key = activity_stream_item_key(stream, post)
      
      # if activity stream item in cache
      if item_id = ::BackupWorker.cache.get(cache_key)
        log_info "Cache hit for FacebookActivityStreamItem key #{cache_key} => #{item_id}"
        @item = ActivityStreamItem.find(item_id) rescue nil
      end
      # if in db
      unless @item
        if @item = stream.items.facebook.find(:first, :conditions => {
          :published_at => Time.at(post.created), 
          :guid => post.id})
          # Save to cache
          ::BackupWorker.cache.set(cache_key, @item.id)
        end
      end
      @item
    end
    
    # Helper for save_posts_* actions. Attempts to keep facebook data synchronized with # FB & database by
    # checking for existence of post in db & updating if found before # trying to add each. 
    def sync_posts(as, posts=[]) 
      posts.each do |p| 
        # Check for duplicate and update if found # Perform find/update/insert inside
        # mutex to ensure consistency among threads, # and to try to prevent max connection db errors from AR
        # deadlocks

        #dbsync_mutex.synchronize do
        # cleanup_connection monkey-patch in ar_thread_patches doesn't seem to work with 
        # named scopes
        FacebookActivityStreamItem.cleanup_connection do
          # If the post item has been saved already
          if f = lookup_activity_stream_item(as, p)
            # check if needs synching
            if FACEBOOK_ACTIVITY_SYNC_ENABLED
              log_debug "Synching FB activity stream item"
              f.sync_from_proxy!(p) if f.needs_sync?(p)
            end
          else
            # Need this b/c we can't call create from a named_scope call and expect 
            # the create to return the scoped STI child - it will return the base class object 
            # (interestingly with the right type attribute set though..)
            log_info "Adding new FB activity stream item"
            item = FacebookActivityStreamItem.create_from_proxy!(as.id, p)
            # Save uniqe db record id to cache
            if item.class == FacebookActivityStreamItem
              cache_key = activity_stream_item_key(as, p)
              log_debug "Saving FacebookActivityStreamItem to cache: #{cache_key} => #{item.id}"
              ::BackupWorker.cache.set(cache_key, item.id)
            end
          end
        end # cleanup_connection
        #end # mutex synchronize
      end # posts.each
    end
  end
end


