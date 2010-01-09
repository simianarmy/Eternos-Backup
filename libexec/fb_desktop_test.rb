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

def profile
  puts "Profile"
  pp @user.profile.inspect
end

def groups
  puts "groups"
  puts @user.groups.inspect
end

def friends
  friend_map = {}
  @friends = @user.friends
  pp @friends.inspect
end

def notifications
  puts "Notifications"
  puts @user.user.notifications.inspect
end

def albums
  albums = @user.albums
  puts "#{albums.size} photo albums"
  puts "Listing ***"
  count = 0
  albums.each do |album|
    puts "\# #{count+=1}"
    puts "#{album.name} #{album.link}"
  end
end

def posts
  puts "Wall posts"
  @user.get_stream.each do |p|
    puts "Author: " + (@user.friend_name(p.id) || 'user')
    pp p.inspect
  end
end

def posts_with_comments
  puts "Wall posts"
  @user.get_stream.each do |p|
    puts "Author: " + (@user.friend_name(p.id) || 'user')
    p.comments = @user.comments(p.data.post_id) if p.data.comments.count.to_i > 0
    pp p.inspect
    if p.data.likes.count.to_i > 0
      puts "***LIKES FOUND"
      pp p.data.likes
    end
  end
end

# Returns user's connections
def connections
  query = "SELECT target_id, target_type, is_following, updated_time, is_deleted FROM connection WHERE source_id = '#{@user.id}'"
  pp @session.fql_query(query)
end
  
# Return stream wall
def stream
  query = "SELECT actor_id, post_id, target_id, created_time, updated_time, attribution, message, attachment, likes, comments, permalink, action_links FROM stream WHERE  source_id='#{@user.id}'"
  pp @session.fql_query(query)
end

# Returns all posts containing user's comment
def user_comments
  query = "SELECT post_id, message FROM stream WHERE post_id IN
    (SELECT post_id FROM comment WHERE post_id IN 
      (SELECT post_id FROM stream WHERE source_id IN
        (SELECT target_id FROM connection WHERE source_id='#{@user.id}')) AND 
      (fromid = '#{@user.id}'))"
  pp @session.fql_query(query)
end

# all items in user's news feed
def news
  query = "SELECT actor_id, post_id, target_id, created_time, updated_time, attribution, message, attachment, likes, comments, permalink, action_links FROM stream WHERE filter_key in (SELECT filter_key FROM stream_filter WHERE uid = '#{@user.id}' AND type = 'newsfeed')"
  pp @session.fql_query(query)
end

# all items by user in user's news feed
def user_news
  query = "SELECT actor_id, post_id, target_id, created_time, updated_time, attribution, message, attachment, likes, comments, permalink, action_links 
    FROM stream 
    WHERE (filter_key in (SELECT filter_key FROM stream_filter WHERE uid = '#{@user.id}' AND type = 'newsfeed')) AND
      (actor_id = '#{@user.id}')"
  pp @session.fql_query(query)
end

def anyone
  query = "SELECT actor_id, post_id, target_id, created_time, updated_time, attribution, message, attachment, likes, comments, permalink, action_links
    FROM stream 
    WHERE (source_id IN (SELECT target_id FROM connection WHERE source_id='#{@user.id}') AND is_hidden = 0)"
#    OR
#    (filter_key in (SELECT filter_key FROM stream_filter WHERE uid = '#{@user.id}' AND type = 'newsfeed'))"

  pp @session.fql_query(query)
end
  
def status
  puts "Status?"
  puts @user.user.get_profile_info.inspect
  @session.post('facebook.status.get', {:uid => user.id}, true)
end

def action_links
  query = "SELECT strip_tags(action_links) FROM stream WHERE source_id = '#{@user.id}'"
  pp @session.fql_query(query)
end

def timed_get
  puts "Stream?"
  @user.session.post('facebook.stream.get', {:source_ids => [1005737378]}, true) do |stuff|
    res = @user.get_stream(:start_at => nil) #Time.now.to_i - (86400 * 60))
    puts "#{res.size} posts"
    pp res
  end
end

### Begin script execution

FacebookDesktopApp::Session.create

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

@user = FacebookBackup::User.new(fb_creds[:uid], fb_creds[:session], fb_creds[:secret])
@user.login!

unless @user.logged_in?
  puts "User login error: " + @user.session.errors
end
@session = @user.session
puts "expired? = " + (@session.expired? ? "yes" : "no")
puts "user has offline permission? " + (@session.user.has_permission?(:offline_access) ? "yes" : "no")

options = {}
#options = {:start_at => 1262801040}
pp @user.get_posts(options)

# Uncomment to debug
#connections
#stream
#profile
#groups
#friends
#notifications
#albums
#posts
# posts_with_comments
#user_comments
#news
#user_news
#anyone
#action_links

### end of script ###

