# $Id$

# Picasa Web Albums backup worker

require File.join(RAILS_ROOT, 'lib/google_backup')

module BackupWorker
  class Picasa < Base
    self.site           = 'picasa'
    self.actions        = [:albums]
    
    attr_accessor :google_client
    
    # Use GoogleBackup module for standardized auth
    def authenticate
      ::SystemTimer.timeout_after(30.seconds) do
        google_client = GoogleBackup::Auth::Picasa.new :auth_token => backup_source.auth_token
        google_client.account_title
      end
    rescue Exception => e
      log :error, "Error authenticating to Picasa: #{e.to_s}"
      false
    end
    
    protected
    
    def save_albums
      log_info "Saving web albums"
  
      begin
        # Get full album list from feed
          # Check each album id against existing list
          # If new, create it & add photos
          # If exists, check existing photo etags against current list
            # update if necessary
          
      rescue Exception => e
        save_error "Error saving photos: #{e.to_s}"
        log :error, e.backtrace
        false
      end
    end
    
    protected
  end
end


