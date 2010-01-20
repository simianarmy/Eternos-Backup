# $Id$

# Picasa Web Albums backup worker

require File.join(File.dirname(__FILE__), '../google/picasa_reader')
require File.join(RAILS_ROOT, 'lib/google_backup')

module BackupWorker
  class Picasa < Base
    self.site           = 'picasa'
    self.actions        = [:albums]
    
    attr_accessor :picasa_client
    
    # Use GoogleBackup module for standardized auth
    def authenticate
      ::SystemTimer.timeout_after(30.seconds) do
        self.picasa_client = GoogleBackup::Auth::Picasa.new :auth_token => backup_source.auth_token
        not self.picasa_client.account_title.blank?
      end
    rescue Exception => e
      save_error "Error authenticating to Picasa: #{e.to_s}"
      false
    end
    
    protected
    
    def save_albums
      log_info "Saving web albums"
  
      begin
        reader = PicasaReader.new picasa_client.client
        # Get full album list from feed, converted to PicasaPhotoAlbum objects
        convert_albums(reader.fetch_albums).each do |album|
          # If album is already backed up, check for modifications
          if pa = backup_source.photo_album(album.id)
            # If modified, synch photos with latest changes
            if pa.modified?(album)
              log_debug "Updating photo album"
              pa.update_album(convert_photos(reader.album_photos(album.id)))
              sleep(PicasaReader.consecutiveRequestDelaySeconds)
            end
          else # otherwise create it
            log_debug "Importing photo album #{album.inspect}"
            new_album = BackupPhotoAlbum.import(backup_source, album)
            new_album.save_photos(convert_photos(reader.album_photos(album.id)))
            sleep(PicasaReader.consecutiveRequestDelaySeconds)
          end
        end
      rescue Exception => e
        save_error "Error saving photos: #{e.to_s}"
        log :error, e.backtrace
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


