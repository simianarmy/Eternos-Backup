# $Id$

# Picasa Web Albums backup worker

require File.join(File.dirname(__FILE__), '../google/picasa_reader')
require File.join(RAILS_ROOT, 'lib/google_backup')

module BackupWorker
  class Picasa < Base
    self.site           = 'picasa'
    self.actions        = {
      EternosBackup::SiteData.defaultDataSet => [:albums]
    }
    
    attr_accessor :picasa_client
    
    # Use GoogleBackup module for standardized auth
    def authenticate
      ::SystemTimer.timeout_after(30.seconds) do
        self.picasa_client = GoogleBackup::Auth::Picasa.new :auth_token => backup_source.auth_token
        not self.picasa_client.account_title.blank?
      end
    rescue Exception => e
      save_exception "Error authenticating to Picasa", e
      false
    end
    
    protected
    
    def save_albums(options)
      log_info "Saving web albums"
  
      begin
        reader = PicasaReader.new picasa_client.client
        # Get full album list from feed, converted to PicasaPhotoAlbum objects
        all_albums = convert_albums(reader.fetch_albums)
        
        # Calculate % completion per album
        steps             = [all_albums.size, 1].max
        percent_per_step  = 100 / steps
        
        log_debug "Beginning to backup in increments of #{percent_per_step}%"
        
        all_albums.each do |album|
          # If album is already backed up, check for modifications
          if pa = backup_source.photo_album(album.id)
            # If modified, synch photos with latest changes
            if pa.modified?(album)
              log_debug "Updating photo album"
              pa.save_album(album, convert_photos(reader.album_photos(album.id)))
              #sleep(PicasaReader.consecutiveRequestDelaySeconds||1)
            end
          else # otherwise create it
            log_debug "Importing photo album #{album.inspect}"
            new_album = BackupPhotoAlbum.import(backup_source, album)
            # Make sure album creation date = published attribute
            new_album.created_at = album.published_at if album.published_at
            # Save all photos in album
            new_album.save_photos(convert_photos(reader.album_photos(album.id)))
            # match cover image url to photo object to set album cover id
            if photo = BackupPhoto.find_by_source_url(album.album.photo_url_s)
              new_album.cover_id = photo.source_photo_id
            end
            new_album.save
            #sleep(PicasaReader.consecutiveRequestDelaySeconds||1)
          end
          update_completion_counter percent_per_step
        end
        set_completion_counter # set completion to 100%
      rescue Exception => e
        save_exception "Error saving web albums", e
        false
      end
    end
    
    protected
    
    def convert_albums(albums)
      albums.map{|a| PicasaPhotoAlbum.new(a)}
    end
    
    def convert_photos(photos)
      photos.map{|p| PicasaPhoto.new(p)}
    end
  end
end


