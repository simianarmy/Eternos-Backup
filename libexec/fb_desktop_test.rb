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

uid = 1005737378
session = '170f5af7fb1c5c3a42b39440-1005737378'
secret = '512abc3078e2fa2035ae73f589e5c381'


user = FacebookBackup::User.new(uid, session, secret)
user.login!

session = user.session
puts "expired? = " + (session.expired? ? "yes" : "no")
puts "permission url = " + session.permission_url('offline_access')

#puts session.inspect
friend_map = {}
friends = user.friends

#puts "user has offline permission? " + (session.user.has_permission?(:offline_access) ? "yes" : "no")

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
