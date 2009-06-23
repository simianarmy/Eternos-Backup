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
require File.join(File.dirname(__FILE__), '/../../lib/facebook/backup_user')
require File.join(RAILS_ROOT, 'app/models/facebook_profile')

module BackupWorker
  class Facebook < BackupWorker::Base    
    @@site = 'facebook'
    
    def backup(job)
      # Get backup start & end dates - nil start dates indicates full backup
      @source = job.backup_source
      @member = @source.member
      
      # Authenticate user first
      @user = FacebookBackup::User.new(@member.facebook_uid, @member.facebook_session_key, @member.facebook_secret_key)
      @user.login!
      return auth_failed(@source) unless @user.logged_in?
      @source.logged_in!
      
      # Now figure out what to backup...
      # Profile can be saved into one db column, easy.
      save_profile
      
      # Pics next
      save_photos
      
      # Friends
      save_friends
      
      # Groups
      save_groups
      
      # Wall stream
      save_posts
    end
    
    protected
    
    def save_profile
      begin
        data = @user.profile
        @member.profile.update_attribute(:facebook_data, data) if valid_profile(data)
      rescue Exception => e
        save_error "Error saving profile data: #{e.to_s}"
        false
      end
    end
    
    def valid_profile(data)
      data[:uid] == @user.id
    end
    
    def save_photos
      @user.albums.each do |album|
        # If album is already backed up
        if fba = @source.photo_album(album.id)
          # Save latest changes
          if fba.modified?(album)
            fba.save_album album, @user.photos(album, :with_tags => true)
          end
        else # otherwise create it
          BackupPhotoAlbum.import(@source, album).save_photos(@user.photos(album, :with_tags => true))
        end
      end
    end
    
    def save_friends
      begin
        fbc = @member.profile.facebook_content || @member.profile.build_facebook_content
        fbc.update_attribute(:friends, @user.friends)
      rescue Exception => e
        save_error "Error fetching facebook friends list: #{e.to_s}"
      end
    end
    
    def save_groups
      begin
        facebook_content.update_attribute(:groups, @user.groups)
      rescue Exception => e
        save_error "Error fetching facebook group list: #{e.to_s}"
      end
    end
    
    def save_posts
      begin
        stream = @member.activity_streams.find_or_initialize_by_backup_site_id(@source.backup_site.id)
        stream.add_items @user.wall_posts(:start_at => stream.latest_activity_time)
        stream.save!
      rescue Exception => e
        save_error "Error fetching facebook wall posts: #{e.to_s}"
      end
    end
    
    def facebook_content
      @member.profile.facebook_content || @member.profile.build_facebook_content
    end
  end
end


