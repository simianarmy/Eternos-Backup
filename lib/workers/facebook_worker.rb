
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

require File.join(File.dirname(__FILE__), 'backupd_worker')

module BackupWorker
  class Facebook < Base
    self.site = 'facebook'
    self.actions = [:profile, :friends, :photos, :posts]
    
    ConsecutiveRequestDelaySeconds = 1
    
    def authenticate
      require File.join(File.dirname(__FILE__), '/../facebook/backup_user')
      write_thread_var :fb_user, user = FacebookBackup::User.new(member.facebook_id, 
        member.facebook_session_key, member.facebook_secret_key
        )
      log_debug "Logging in Facebook user => #{user.id}"
      user.login!
      unless user.logged_in?
        save_error('Error logging in to Facebook: ' <<  
          (user.session.errors ? user.session.errors : 'Unkown error'))
        return false
      end
      backup_source.logged_in!
      true
    end
    
    protected
    
    def save_profile
      data = fb_user.profile
      member.profile.update_attribute(:facebook_data, data) if valid_profile(data)
      update_completion_counter
      true
    rescue Exception => e
      save_error "Error saving profile data: #{e.to_s}"
      log :error, e.backtrace
      false
    end
    
    def save_friends
      facebook_content.update_attribute(:friends, fb_user.friends.map(&:name))
      facebook_content.update_attribute(:groups, fb_user.groups)
      update_completion_counter
      true
    rescue Exception => e
      save_error "Error fetching facebook friends list: #{e.to_s}"
      log :error, e.backtrace
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
            #sleep(ConsecutiveRequestDelaySeconds)
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
      save_error "Error saving photos: #{e.to_s}"
      log :error, e.backtrace
      false
    end

    def save_posts
      log_debug "Fetching wall posts"
      unless as = member.activity_stream || member.create_activity_stream
        raise "Unable to get member activity stream" 
      end
      options = {}
      if item = as.items.facebook.latest(1).first
        options[:start_at] = item.published_at.to_i
        log_debug "starting at #{options[:start_at]}"
      end
      fb_user.wall_posts(options).each do |p| 
        # Add author name if author != user
        p.author = fb_user.friend_name(p.id) if p.id != fb_user.id
        as.items << FacebookActivityStreamItem.create_from_proxy(p)
      end
      update_completion_counter
      true
    rescue Exception => e
      save_error "Error fetching facebook wall posts: #{e.to_s}"
      log :error, e.backtrace
      false
    end

    private
    
    def fb_user
      thread_var(:fb_user)
    end
    
    def valid_profile(data)
      data && data.any?
    end
    
    def facebook_content
      member.profile.facebook_content || member.profile.build_facebook_content
    end
  end
  
  class FacebookStandalone < Facebook 
    include BackupWorker::Standalone
  end
  
  class FacebookQueueRunner < Facebook
    include BackupWorker::QueueRunner
  end
end


