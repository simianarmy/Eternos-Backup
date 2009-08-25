# $Id$

# Facebook Desktop sandbox

$: << File.dirname(__FILE__) + '/../../eternos.com/lib'
require 'rubygems'
require 'pp'

ENV['DAEMON_ENV'] = RAILS_ENV = 'test'

require File.dirname(__FILE__) + '/../config/environment'
require 'active_support'
require 'facebook_desktop'
require RAILS_ROOT + '/vendor/gems/simianarmy-facebooker-1.0.40/lib/facebooker'
require File.dirname(__FILE__) + '/../lib/facebook/backup_user'

FacebookDesktopApp::Session.create
#puts session.login_url
#gets
# Marc
uid = 1005737378
#session = 'c4c3485e22162aeb0be835bb-1005737378'
secret = '6ef09f021c983dbd7d04a92f3689a9a5'
# Andy
#uid = 504883639
#session = '2.DPd4uDYC2w7fBrDtg3IRZA__.86400.1246140000-504883639'
#secret = 'oMlcrlaGX_8C6b3_C9oXqw__'
# Eric
#uid = 657525024
session = "2.frBFfjmNGKIwJC2trkpOsw__.86400.1250539200-657525024"
#secret =  "rSE_VQ6iho3sIX_jL2SBZg__"

user = FacebookBackup::User.new(uid, session, secret)
user.login!

session = user.session
puts "expired? = " + (session.expired? ? "yes" : "no")
puts "permission url = " + session.permission_url('offline_access')

#puts session.inspect
puts session.user.friends
#puts "user has offline permission? " + (session.user.has_permission?(:offline_access) ? "yes" : "no")

#puts "groups"
#puts user.groups.inspect

#puts "Notifications"
#puts user.user.notifications.inspect

albums = user.albums
puts "#{albums.count} photo albums"
puts "Listing ***"
count = 0
albums.each do |album|
  puts "\# #{count+=1}"
  puts "#{album.name} #{album.link}"
end

user.wall_posts.each do |p|
  puts p.inspect
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
