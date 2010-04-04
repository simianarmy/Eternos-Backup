
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

module BackupWorker
  class Facebook < Base
    self.site = 'facebook'
    self.actions = [#:profile, :friends, :photos, 
      :posts]
    
    ConsecutiveRequestDelaySeconds = 1
    
    attr_accessor :fb_user
    
    def authenticate
      self.fb_user = user = FacebookBackup::User.new(member.facebook_id, 
        member.facebook_session_key, member.facebook_secret_key
        )
      log_debug "Logging in Facebook user => #{user.id}"
      user.login!
      
      if user.logged_in?
        backup_source.logged_in!
        true
      else 
        save_error('Error logging in to Facebook: ' <<  
          (user.session.errors ? user.session.errors : 'Unkown error'))
        false
      end
    end
    
    protected
    
    def save_profile
      log_debug "saving profile"
      data = fb_user.profile
      member.profile.update_attribute(:facebook_data, data) if valid_profile(data)
      update_completion_counter
      sleep(ConsecutiveRequestDelaySeconds * 2)
      true
    rescue Exception => e
      save_exception "Error saving profile data", e
      false
    end
    
    def save_friends
      log_debug "saving friends"
      if friends = fb_user.friends
        facebook_content.update_attribute(:friends, friends.map(&:name))
      end
      if groups = fb_user.groups
        facebook_content.update_attribute(:groups, groups)
      end
      update_completion_counter
      sleep(ConsecutiveRequestDelaySeconds * 2)
      true
    rescue Exception => e
      save_exception "Error fetching facebook friends list", e
      false
    end

    def save_photos
      log_debug "Fetching photos"
      
      fb_user.albums.each do |album|
        # If album is already backed up, check for modifications
        if fba = backup_source.photo_album(album.id)
          # Save latest changes
          if fba.modified?(album)
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
      sleep(ConsecutiveRequestDelaySeconds * 2)
      true
    rescue Exception => e
      save_exception "Error saving photos", e
      false
    end

    def save_posts
      log_debug "Fetching activity stream"
      unless as = member.activity_stream || member.create_activity_stream
        raise "Unable to get member activity stream" 
      end
      options = {}

      ActivityStreamItem.cleanup_connection do
        if item = as.items.facebook.newest
          # Don't limit to last item's date otherwise we'll miss new comments on older posts...
          # We may want to use 2 or 3 days back from more recent
          #options[:start_at] = item.published_at.to_i
          log_debug "starting at #{options[:start_at]}"
        end
      end
      fb_user.get_posts(options).each do |p|
        # Check for duplicate and update if found
        found = as.items.facebook.sync_from_proxy!(p) do |scope|
          # uniqueness check depends on facebook - it might change..
          scope.find_by_guid_and_source_url(p.id, p.source_url)
          #scope.find_by_published_at_and_message(Time.at(p.created), p.message)
        end
        # Need this b/c we can't call create from a named_scope call and expect 
        # the create to return the scoped STI child - it will return the base class object 
        # (interestingly with the right type attribute set though..)
        unless found
          log_debug "Adding facebook activity stream item"
          FacebookActivityStreamItem.create_from_proxy!(as.id, p)
        end
      end
      update_completion_counter
      true
    rescue Exception => e
      save_exception "Error fetching facebook wall posts", e
      false
    end

    protected
    
    def valid_profile(data)
      data && data.any?
    end
    
    def facebook_content
      member.profile.facebook_content || member.profile.build_facebook_content
    end
  end
end


