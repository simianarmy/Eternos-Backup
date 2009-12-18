# $Id$

# Facebook Desktop sandbox

$: << File.dirname(__FILE__) + '/../../eternos.com/lib'
require 'rubygems'
require 'pp'

ENV['DAEMON_ENV'] = RAILS_ENV = 'test'

require File.dirname(__FILE__) + '/../config/environment'
require File.join(RAILS_ROOT, 'config', 'environment')
require 'facebook_desktop'
require File.dirname(__FILE__) + '/../lib/facebook/backup_user'

FacebookDesktopApp::Session.create
#puts session.login_url
#gets
# Marc
fb_users = {
  :good => {
    :uid => 1005737378,
    :session => '5dcf12fae9643866f7a65388-1005737378',
    :secret => 'af1504279826a5737c15fd6fb873353b',
  },
  :fail => {
    #failed
    :uid => 100000157118983,
    :session => '4ec363616f7d765ac462fd2f-100000157118983',
    :secret => '917deaf04af2e48cad0e96c97891c7b5',
  }
}
fb_creds = fb_users[:good]

user = FacebookBackup::User.new(fb_creds[:uid], fb_creds[:session], fb_creds[:secret])
user.login!

unless user.logged_in?
  puts "User login error: " + user.session.errors
end
session = user.session
puts session.inspect
puts "expired? = " + (session.expired? ? "yes" : "no")
puts "user has offline permission? " + (session.user.has_permission?(:offline_access) ? "yes" : "no")

puts "Profile"
puts user.profile.inspect

friend_map = {}
friends = user.friends

#puts "groups"
#puts user.groups.inspect

#puts "Notifications"
#puts user.user.notifications.inspect

albums = user.albums
puts "#{albums.size} photo albums"
puts "Listing ***"
count = 0
albums.each do |album|
  puts "\# #{count+=1}"
  puts "#{album.name} #{album.link}"
end

user.wall_posts.each do |p|
  puts "Author: " + (user.friend_name(p.id) || 'user')
end
#puts "Status?"
#puts user.user.get_profile_info.inspect
#user.session.post('facebook.status.get', {:uid => user.id}, true)

#puts "Stream?"
#user.session.post('facebook.stream.get', {:source_ids => [1005737378]}, true) do |stuff|
#res = user.wall_posts(:start_at => nil) #Time.now.to_i - (86400 * 60))
#puts "#{res.size} posts"
#pp res

#pp user.friends
