# $Id$

# linkedin backup daemon.

require 'linkedin2'

module BackupWorker

  class Linkedin < Base
    self.site           = 'linkedin'
    self.actions        = {
      EternosBackup::SiteData.defaultDataSet => [:linkedin]
    }

    attr_accessor :linkedin_client
    
    # Returns TRUE iff account is authenticated
    def authenticate
      ::SystemTimer.timeout_after(30.seconds) do
        self.linkedin_client = if backup_source.auth_token && backup_source.auth_secret
          LinkedinBackup::OAuth.authorization(backup_source.auth_token, backup_source.auth_secret)
        end
      end
      # Verify authenticated by fetching name from profile
      !self.linkedin_client.nil? && self.linkedin_client.authorized?
    rescue Exception => e
      save_exception "Error authenticating to Linked In", e
      false
    end
    
    protected
    
    def save_linkedin(options)
      log_info "saving linkedin"

	    comment_like  = linkedin_client.get_network_update('STAT')
      info          = linkedin_client.get_profile('all')
      cmpies        = linkedin_client.get_network_update('CMPY')
	    ncons         = linkedin_client.get_network_update('NCON')
      user = backup_source.linkedin_user || backup_source.linkedin_user.new
 	    user.update_profile(info, comment_like, cmpies, ncons)
    end
  end
end


