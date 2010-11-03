# $Id$

module FacebookBackup
  class FacebookComment < Hashie::Mash
    def user=(fb_user)
      self.username     = fb_user.name
      self.user_pic     = fb_user.pic_square
      self.profile_url  = fb_user.profile_url
    end
    
    # Returns commenter user data in hash format for external use
    def user_data
      {:username => self.username,
       :pic_url => self.user_pic,
       :profile_url => self.profile_url
      }
    end
  end
end