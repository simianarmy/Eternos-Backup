# $Id

# Backup Desktop App User object

#require 'active_support' # for mattr_reader
require RAILS_ROOT + '/lib/facebook_desktop'
require RAILS_ROOT + '/lib/facebook_user_profile'
require RAILS_ROOT + '/lib/facebook_photo_album'
require File.dirname(__FILE__) + '/facebook_activity'
require File.dirname(__FILE__) + '/facebook_comment'
require File.dirname(__FILE__) + '/../request_scheduler'

module FacebookBackup
  # Wraps Facebooker::User class
  class User
    class FacebookNetworkError < Exception; end
    
    attr_reader :id, :session_key, :profile
    attr_accessor :secret_key, :scheduler
    
    delegate :name, :to => :user
    
    def initialize(uid, session_key, secret_key=nil)
      @id, @session_key, @secret_key = uid, session_key, secret_key
      @session = nil
      @facebook_desktop_config = File.join(RAILS_SHARED_CONFIG_DIR, 'facebooker_desktop.yml')
      @scheduler = RequestScheduler.new('FacebookBackup', :delay => 1000)
    end
    
    def login!
      session.connect(session_key, id, nil, secret_key)
      user
    end
    
    def session
      @session ||= FacebookDesktopApp::Session.create @facebook_desktop_config
    end
    
    def user
      @user ||= facebook_request { session.user }
    end
    
    def logged_in?
      facebook_request { session.verify }
    end
    
    # Returns facebook (cached) profile in hash, with keys from Facebooker::User::FIELDS
    def profile
      @profile ||= facebook_request { FacebookUserProfile.populate(user) }
    end
    
    def albums
      facebook_request { user.albums.collect {|a| FacebookPhotoAlbum.new(a)} }
    end
    
    def photos(album, options={})
      # Multiquery for photos info + tags
      photos = []
      if options[:with_tags]
        photo_query = "SELECT pid, aid, owner, src, src_big, src_small, link, caption, created " +
          "FROM photo WHERE aid= '#{album.id}'"
        tag_query = "SELECT pid, text FROM photo_tag WHERE pid IN (SELECT pid FROM #query1)"

        multiquery = {'query1' => photo_query, 'query2' => tag_query}
        resp = facebook_request { session.fql_multiquery(multiquery) }
        
        photos = resp['query1']
        # Format tags keyed by photo id
        tags = resp['query2'].inject({}) do |result, element| 
          (result[element['pid'].to_i] ||= []) << element['text']
          result
        end
      else
        photos = facebook_request { session.get_photos(nil, nil, album.id) }
      end
      # We could just return photos and let the client convert them if we wanted to be
      # all general-purpose and all, but YAGNI, right?
      photos.map do |p|
        DaemonKit.logger.debug "FQL Photo => #{p.inspect}"
        photo = FacebookPhoto.new(p)
        # If tags, find tags for the photo and collect into array
        photo.tags = tags[p.id] if tags
        DaemonKit.logger.debug "FacebookPhoto = #{photo.inspect}"
        photo
      end
    end
    
    # Memoized
    def friends
      # Use FQL for faster query
      query = "SELECT uid, name, pic_square, profile_url FROM user WHERE uid IN (SELECT uid2 FROM friend WHERE uid1 = #{id})"
      @friends ||= facebook_request { session.fql_query(query) }
    end
    
    def friend(uid)
      friends.detect {|f| f.uid == uid.to_i}
    end
    
    def friend_name(uid)
      friend(uid).name rescue nil
    end
    
    def groups
      facebook_request { user.groups.map(&:group_type).reject {|g| g == 'Facebook'} }
    end
    
    # Returns array of FacebookActivity objects
    # Includes:
    # => posts coming from this user & comments with threads
    # Options:
    # => start_at: unixtime - minimum created_time value
    # => user_posts_only: boolean - set to true if only user-created posts should be included
    def get_posts(options={})
      # to retrieve wall posts & posts made on other pages

      # Massive FQL query - may contain duplicates
      query = build_stream_fql("(source_id = '#{id}') OR
        ((filter_key IN
          (SELECT filter_key FROM stream_filter WHERE uid = '#{id}' AND type = 'newsfeed')) AND 
          (actor_id = '#{id}')) OR
        (post_id IN
          (SELECT post_id FROM comment WHERE post_id IN 
            (SELECT post_id FROM stream WHERE source_id IN
              (SELECT target_id FROM connection WHERE source_id='#{id}')) AND 
          (fromid = '#{id}')))", 
        options)
      
      posts = facebook_request {
        session.fql_query(query).reject {|p| (p['actor_id'] != id.to_s) && options[:user_posts_only]}.map do |p| 
          FacebookActivity.new(p)
        end
      }.uniq
      # post-process results
      posts_with_comments = []
      
      posts.each do |p|
        # Add author name if author != user
        p.author = friend_name(p.author_id) if p.author_id != id.to_s
        # Collect posts to fetch all comments
        posts_with_comments << "'#{p.id}'" if p.has_comments?
        # Collect names of anyone who 'liked' this post
        p.likers.map!{|uid| friend(uid).name rescue ''} if p.likers
      end
      # Collect all comments at once
      comments = get_comments(posts_with_comments.uniq)
      # then add comments to their posts
      posts.each do |p|
        p.comments = comments[p.id] if comments[p.id]
      end
      posts
    end

    protected
      
    # Helper for making network requests using the Facebooker API
    # Handles scheduling & Curl exceptions  
    def facebook_request
      begin
        @scheduler.execute { yield }
      rescue Curl::Err => e
        raise FacebookNetworkError, "#{e.class.name}: #{e.message}"
      end
    end
    
    def build_stream_fql(conditions, options)
      query = "SELECT #{stream_query_columns} FROM stream WHERE (#{conditions})"
      query << " AND (created_time > #{options[:start_at]})" if options[:start_at]
      query << " ORDER BY created_time LIMIT 400"
    end
    
    def build_comment_fql(conditions, options={})
      query = "SELECT #{comment_query_columns} FROM comment WHERE (#{conditions})"
      query << " AND (time > #{options[:start_at]})" if options[:start_at]
      query << " ORDER BY time LIMIT 400"
    end
    
    def stream_query_columns
      "actor_id, post_id, target_id, created_time, updated_time, strip_tags(attribution), message, attachment, likes, comments.count, permalink, action_links"
    end
    
    def comment_query_columns
      "post_id, fromid, time, text, username"
    end
    
    # Collects post's comments, returns results as hash of arrays, 
    # with key = post_id, value = comments
    def get_comments(post_ids)
      returning Hash.new do |res| 
        # Perform query to fetch commenter name with comment, sorted by time
        query = build_comment_fql("post_id IN (#{post_ids.join(',')})")
        name_query = "SELECT uid, name, pic_square, profile_url FROM user WHERE uid IN (SELECT fromid FROM #query1)"
        
        queries = {:query1 => query, :query2 => name_query}
        results = facebook_request { session.fql_multiquery(queries) }
        # Build userid => user map
        uid_map = results['query2'].inject({}) {|h, user| h[user.id.to_s] = user; h}
        
        results['query1'].each_with_index do |comment, i|
          fb_comment = FacebookComment.new(comment)

          if fb_comment.username.blank? && uid_map[fb_comment.fromid]
            fb_comment.user = uid_map[fb_comment.fromid]
          end
          (res[fb_comment.post_id] ||= []) << fb_comment
        end
      end
    end
  end
end