
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
require 'facebooker'
require File.join(File.dirname(__FILE__), '/../facebook/backup_user')



module BackupWorker
  class Facebook < Base
    self.site = 'facebook'
    self.actions = [:profile, :friends, :photos, :posts]
    self.increment_step = 100 / self.actions.size
    ConsecutiveRequestDelaySeconds = 2
    
    def authenticate
      @member = @source.member
      @user = FacebookBackup::User.new(@member.facebook_id, @member.facebook_session_key, @member.facebook_secret_key)
      log_debug "Facebook user => #{@user.inspect}"
      @user.login!
      unless @user.logged_in?
        save_error 'Error logging in to Facebook'
        return false
      end
      @source.logged_in!
      
      return true
    end
    
    protected
    
    def save_profile
      data = @user.profile
      @member.profile.update_attribute(:facebook_data, data) if valid_profile(data)
      update_completion_counter
      true
    rescue Exception => e
      save_error "Error saving profile data: #{e.to_s}"
      log :error, e.backtrace
      false
    end
    
    def save_friends
      facebook_content.update_attribute(:friends, @user.friends)
      facebook_content.update_attribute(:groups, @user.groups)
      update_completion_counter
      true
    rescue Exception => e
      save_error "Error fetching facebook friends list: #{e.to_s}"
      log :error, e.backtrace
      false
    end

    def save_photos
      @user.albums.each do |album|
        # If album is already backed up, check for modifications
        if fba = @source.photo_album(album.id)
          # Save latest changes
          log_debug "Saving Facebook album: #{album.inspect}"
          fba.save_album(album, @user.photos(album, :with_tags => true)) if fba.modified?(album)
        else # otherwise create it
          photos = @user.photos(album, :with_tags => true)
          BackupPhotoAlbum.import(@source, album).save_photos(photos)
        end
        sleep(ConsecutiveRequestDelaySeconds)
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
      options = {}
      if item = @member.activity_stream.items.facebook.latest.first
        options[:start_at] = item.published_at.to_i
        log_debug "starting at #{options[:start_at]}"
      end
      @user.wall_posts(options).each do |p| 
        @member.activity_stream.items << FacebookActivityStreamItem.create_from_proxy(p)
      end
      update_completion_counter
      true
    rescue Exception => e
      save_error "Error fetching facebook wall posts: #{e.to_s}"
      log :error, e.backtrace
      false
    end

    private
    
    def valid_profile(data)
      data && data.any?
    end
    
    def facebook_content
      @member.profile.facebook_content || @member.profile.build_facebook_content
    end
  end
  
  class FacebookStandalone < Facebook 
    include BackupWorker::Standalone
  end
  
  class FacebookQueueRunner < Facebook
    include BackupWorker::QueueRunner
  end
end


