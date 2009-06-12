# $Id$

# Facebook Desktop sandbox

$: << 'vendor/facebooker-1.0.31-patched/lib'
require 'rubygems'
require 'facebooker'

env ||= 'development'

fb_conf_file = File.dirname(__FILE__) + '/../config/facebooker.yml'
fb_config = begin
  config = YAML.load_file(fb_conf_file)
  config[env]
rescue
  puts "Unable to load #{fb_conf_file}: $!"
  exit
end

Facebooker::apply_configuration(fb_config) 
session = Facebooker::Session::Desktop.create( fb_config['api_key'] , fb_config['secret_key'] )

puts "Paste the URL into your web browser and login:"
puts session.login_url
gets
puts "expired? = " + (session.expired? ? "yes" : "no")
#puts "permission url = " + session.permission_url('offline_access')

puts session.inspect
session.secure_with!('c4c3485e22162aeb0be835bb-1005737378', 1005737378, nil, '6ef09f021c983dbd7d04a92f3689a9a5')
puts session.inspect
exit unless session.secured?
puts "session = " + session.session_key
puts "user has offline permission? " + (session.user.has_permission?(:offline_access) ? "yes" : "no")

puts session.user.status

friends = session.user.friends!( :name, :status  )
puts "What are your friends doing?"
friends.each do |friend|
  puts "#{friend.name} #{friend.status}"
end

puts "Photo albums"
session.user.albums.each do |album|
  puts "#{album.name} #{album.link}"
end