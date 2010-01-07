# $Id$

class FacebookComment < Hashie::Mash
  def user=(fb_user)
    self.username     = fb_user.name
    self.user_pic     = fb_user.pic_square
    self.profile_url  = fb_user.profile_url
  end
end