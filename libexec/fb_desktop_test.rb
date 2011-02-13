# $Id$

# Facebook Desktop sandbox
#
# *** Set FB_USER environment variable before running ***
#

$: << File.dirname(__FILE__) + '/../../eternos_www/lib'

ENV['DAEMON_ENV'] = RAILS_ENV = 'test'

require File.dirname(__FILE__) + '/../config/environment'
require File.join(RAILS_ROOT, 'config', 'environment')
require 'facebook_desktop'
require File.dirname(__FILE__) + '/../lib/backup_helper'
require File.dirname(__FILE__) + '/../lib/worker_job'
require File.dirname(__FILE__) + '/../lib/facebook/backup_user'
require 'pp'
require 'yaml'

DaemonKit.logger = Rails.logger 

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
  
  albums.each_with_index do |album, count|
    puts "\# #{count+1}"
    puts "#{album.name} #{album.link}"
  end
end

def photos
  @user.albums.each do |album|
    puts "Album: #{album.name}"
    @user.photos(album, :with_tags => true).each do |p|
      puts p.inspect
    end
  end
end

def posts
  puts "Wall posts"
  @user.get_posts.each do |p|
    puts "Author: " + (@user.friend_name(p.id) || 'user')
    pp p.inspect
  end
end

def posts_in_range
  min_date = nil
  max_date = 1.months.ago.to_i
  puts "Wall posts in range #{min_date} .. #{max_date}"
  pp_all @user.get_posts :start_at => min_date, :end_at => max_date
end
  
def posts_with_comments
  puts "Wall posts"
  pp_all @user.get_posts
end

def posts_on_other_walls
  puts "Other wall posts"
  @user.get_posts_to_friends do |posts|
    pp_all posts
  end
end

def messages
  puts "Messages"
  @user.threads.each do |t|
    pp "Got thread #{t.inspect}"
    puts "thread id = " + t.id.to_s
    t = @user.messages(t)
    pp "Proxy thread: #{t.class.to_s}"
    t.messages.each do |msg|
      puts "message #{msg.id}"
      puts msg.attachment.inspect
    end
    puts '*' * 50
  end
end

def pp_all(arr)
  arr.each { |p| pp p.inspect, "\n" }
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
  multi = {:query1 => "SELECT target_id FROM connection WHERE source_id='#{@user.id}'",
    :query2 => "SELECT post_id FROM stream WHERE source_id IN (SELECT target_id FROM #query1)",
    :query3 => "SELECT post_id FROM comment WHERE post_id IN (SELECT post_id FROM #query2)", # AND (fromid = '#{@user.id}')",
    :query4 => "SELECT post_id, message FROM stream WHERE post_id IN (SELECT post_id FROM #query3)"
  }
  # query = "SELECT post_id, message FROM stream WHERE post_id IN
  #     (SELECT post_id FROM comment WHERE post_id IN 
  #       (SELECT post_id FROM stream WHERE source_id IN
  #         (SELECT target_id FROM connection WHERE source_id='#{@user.id}')) AND 
  #       (fromid = '#{@user.id}'))"
  pp @session.fql_multiquery(multi)
end

def comments_with_user_info
  query = "SELECT post_id, fromid, time, text, username FROM comment WHERE post_id IN 
       (SELECT post_id FROM stream WHERE source_id IN
         (SELECT target_id FROM connection WHERE source_id='#{@user.id}')) AND 
       (fromid = '#{@user.id}')"
  name_query = "SELECT uid, name, pic_square, profile_url FROM user WHERE uid IN (SELECT fromid FROM #query1)"
    
  queries = {:query1 => query, :query2 => name_query}
  results = @session.fql_multiquery(queries)
  puts "Comments: "
  pp results['query1']
  uid_map = results['query2'].inject({}) {|h, user| h[user.id] = user; h}
  puts "Users: "
  pp uid_map.inspect
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

def pages_admined
  puts "Pages we admin: "
  pp @user.administered_pages
end

###

unless fb_user = ENV['FB_USER']
  puts "FB_USER param required!"
  exit
end

FacebookDesktopApp::Session.create

fb_users = YAML.load_file(File.join(DAEMON_ROOT, 'config', 'fb_users.yml'))
puts fb_users.inspect
puts "FB User: " + fb_user
fb_creds = fb_users[fb_user]
puts fb_creds.inspect

puts "Logging in #{fb_creds['uid']}"
@user = FacebookBackup::User.new(fb_creds['uid'], fb_creds['session'], fb_creds['secret'])
@user.login!

unless @user.logged_in?
  puts "User login error: " + @user.session.errors
end
@session = @user.session
puts "expired? = " + (@session.expired? ? "yes" : "no")
puts "user has offline permission? " + (@session.user.has_permission?(:offline_access) ? "yes" : "no")

options = {}

#options = {:start_at => 1262801040}

# Uncomment to debug
#pages_admined
#connections
#stream
#profile
#groups
#friends
#notifications
#albums
#photos
posts
#posts_in_range
#posts_with_comments
#posts_on_other_walls
#user_comments
#comments_with_user_info
#news
#user_news
#anyone
#action_links
#messages

### end of script ###



### Begin script execution

