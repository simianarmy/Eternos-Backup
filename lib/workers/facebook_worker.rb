
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
require 'active_support/core_ext/module/attribute_accessors' # for cattr_reader


module BackupWorker
  class Facebook < Base
    cattr_reader :site, :actions, :increment_step
    @@site = 'facebook'
    @@actions = [:profile, :friends, :photos, :posts]
    @@increment_step = 100 / self.actions.size
    ConsecutiveRequestDelaySeconds = 2
    
    def authenticate
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
      begin
        data = @user.profile
        member_profile.update_attribute(:facebook_data, data) if valid_profile(data)
      rescue Exception => e
        save_error "Error saving profile data: #{e.to_s}"
        log :error, e.backtrace
        return false
      end
      true
    end
    
    def valid_profile(data)
      data && data.any?
    end
    
    def save_friends
      begin
        facebook_content.update_attribute(:friends, @user.friends)
        facebook_content.update_attribute(:groups, @user.groups)
      rescue Exception => e
        save_error "Error fetching facebook friends list: #{e.to_s}"
        log :error, e.backtrace
        return false
      end
      true
    end
    
    def save_photos
      begin
        @user.albums.each do |album|
          log_debug "Saving Facebook album: #{album.inspect}"
          # If album is already backed up, check for modifications
          if fba = @source.photo_album(album.id)
            # Save latest changes
            fba.save_album(album, @user.photos(album, :with_tags => true)) if fba.modified?(album)
          else # otherwise create it
            photos = @user.photos(album, :with_tags => true)
            BackupPhotoAlbum.import(@source, album).save_photos(photos)
          end
          sleep(ConsecutiveRequestDelaySeconds)
        end
      rescue Exception => e
        save_error "Error saving photos: #{e.to_s}"
        log :error, e.backtrace
        return false
      end
      true
    end
    
    def save_posts
      begin
        stream = @member.activity_streams.find_or_create_by_backup_site_id(@source.backup_site.id)
        posts = @user.wall_posts(:start_at => stream.latest_activity_time).map do |p| 
          FacebookActivityStreamItem.create_from_proxy(stream.id, p)
        end
      rescue Exception => e
        save_error "Error fetching facebook wall posts: #{e.to_s}"
        log :error, e.backtrace
        return false
      end
      true
    end
    
    def facebook_content
      member_profile.facebook_content || member_profile.build_facebook_content
    end
    
    def member_profile
      @member.profile || @member.create_profile
    end
  end
  
  class FacebookStandalone < Facebook 
    include BackupWorker::Standalone
  end
  
  class FacebookQueueRunner < Facebook
    include BackupWorker::QueueRunner
  end
end


