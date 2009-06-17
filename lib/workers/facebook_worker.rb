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
      
      # Wall stream
    end
    
    protected
    
    def save_profile
      begin
        data = @user.profile
        @member.profile.update_attribute(:facebook_data, data) if valid_profile(data)
      rescue Exception => e
        log :error, "Unable to save profile data: #{e.to_s}\n\n data: #{data.to_s}"
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
          fba.modify(album) if fba.modified?(album)
        else # otherwise create it
          BackupPhotoAlbum.import(@source, album)
        end
      end
    end
  end
end


