# $Id$

# Facebook Desktop sandbox

$: << File.dirname(__FILE__) + '/../../eternos.com/lib'
require 'rubygems'
require 'pp'

require File.dirname(__FILE__) + '/../config/environment'
require File.dirname(__FILE__) + '/../lib/facebook/backup_user'
ENV['DAEMON_ENV'] = 'test'

user = FacebookBackup::User.new(1005737378, 'c4c3485e22162aeb0be835bb-1005737378', '6ef09f021c983dbd7d04a92f3689a9a5')
user.login!

#puts "expired? = " + (session.expired? ? "yes" : "no")
#puts "permission url = " + session.permission_url('offline_access')

#puts session.inspect
#exit unless session.secured?

#puts "user has offline permission? " + (session.user.has_permission?(:offline_access) ? "yes" : "no")

#puts "groups"
#puts user.groups.inspect

#puts "Notifications"
#puts user.user.notifications.inspect

# puts "Photo albums"
# user.albums.each do |album|
#   puts "#{album.name} #{album.link}"
#   #puts album.inspect
#   user.photos(album).each do |p|
#     #puts p.inspect
#     puts "#{p.caption} - #{p.source_url}"
#     puts "Tags: #{p.tags.inspect}"
#   end
# end

#puts "Status?"
#puts user.user.get_profile_info.inspect
#user.session.post('facebook.status.get', {:uid => user.id}, true)

puts "Stream?"
#user.session.post('facebook.stream.get', {:source_ids => [1005737378]}, true) do |stuff|
res = user.wall_posts(:start_at => nil) #Time.now.to_i - (86400 * 60))
puts "#{res.size} posts"
pp res
