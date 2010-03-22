# $Id

# Backup Desktop App User object

#require 'active_support' # for mattr_reader
require RAILS_ROOT + '/lib/facebook_desktop'
require RAILS_ROOT + '/lib/facebook_user_profile'
require RAILS_ROOT + '/lib/facebook_photo_album'
require File.dirname(__FILE__) + '/facebook_activity'
require File.dirname(__FILE__) + '/facebook_comment'
require File.dirname(__FILE__) + '/facebook_query'
require File.dirname(__FILE__) + '/facebook_request'

module FacebookBackup
  # Wraps Facebooker::User class
  class User
    
    attr_reader :id, :session_key, :profile
    attr_accessor :secret_key
    
    delegate :name, :to => :user
    
    def initialize(uid, session_key, secret_key=nil)
      @id, @session_key, @secret_key = uid, session_key, secret_key
      @session = nil
      @facebook_desktop_config = File.join(RAILS_SHARED_CONFIG_DIR, 'facebooker_desktop.yml')
      @request = FacebookBackup::Request.new(@id)
      @query = FacebookBackup::Query.new(@id)
    end
    
    def login!
      session.connect(session_key, id, nil, secret_key)
      user
    end
    
    def session
      @session ||= FacebookDesktopApp::Session.create @facebook_desktop_config
    end
    
    def user
      @user ||= @request.do_request { session.user }
    end
    
    def logged_in?
      @request.do_request { session.verify }
    end
    
    # Returns facebook (cached) profile in hash, with keys from Facebooker::User::FIELDS
    def profile
      @profile ||= @request.do_request { FacebookUserProfile.populate(user) }
    end
    
    def albums
      @request.do_request { user.albums.collect {|a| FacebookPhotoAlbum.new(a)} }
    end
    
    def photos(album, options={})
      # Multiquery for photos info + tags
      photos = []
      if options[:with_tags]
        resp = @request.do_request { session.fql_multiquery(@query.photos_multi_fql(album.id)) }
        
        photos = resp['query1']
        # Format tags keyed by photo id
        tags = resp['query2'].inject({}) do |result, element| 
          (result[element['pid'].to_i] ||= []) << element['text']
          result
        end
      else
        photos = @request.do_request { session.get_photos(nil, nil, album.id) }
      end
      # We could just return photos and let the client convert them if we wanted to be
      # all general-purpose and all, but YAGNI, right?
      photos.map do |p|
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
      @friends ||= @request.do_request { session.fql_query(@query.friends_fql) }
    end
    
    def friend(uid)
      friends.detect {|f| f.uid == uid.to_i}
    end
    
    def friend_name(uid)
      friend(uid).name rescue nil
    end
    
    def groups
      @request.do_request { user.groups.map(&:group_type).reject {|g| g == 'Facebook'} }
    end
    
    # Returns array of FacebookActivity objects
    # Includes:
    # => posts coming from this user & comments with threads
    # Options:
    # => start_at: unixtime - minimum created_time value
    # => user_posts_only: boolean - set to true if only user-created posts should be included
    def get_posts(options={})
      # to retrieve wall posts & posts made on other pages
      res = []
      # multiple FQL queries - may contain duplicates
      res = @request.do_request {
        session.fql_query @query.posts_multi_fql(options)
      }
      # This multiquery is for finding posts the user made on other walls
      response = @request.do_request { 
        session.fql_multiquery(@query.friends_wall_posts_multi_fql)
      }
      # TODO: Still need a query for comments on posts on other walls...
      
      if response && response['query2']
        res += response['query2']
      end
      # Collect facebook response into FacebookActivity collection
      posts = res.reject { |post| 
        (post['actor_id'] != id.to_s) && options[:user_posts_only]
      }.map { |act| FacebookActivity.new(act) }
      
      DaemonKit.logger.debug "FB stream & posts => #{posts.inspect}"
      unless posts
        DaemonKit.logger.error "Facebook Backup: Unable to fetch posts array for #{id}"
        return []
      end
      # post-process results
      posts.uniq!
      posts_with_comments = []
      
      posts.each do |p|
        # Add author name if author != user
        p.author = friend_name(p.author_id) if p.author_id != id.to_s
        # Collect posts to fetch all comments
        posts_with_comments << "'#{p.id}'" if p.has_comments?
        # Collect names of anyone who 'liked' this post
        p.likers.map!{|uid| friend(uid).name rescue ''} if p.likers
      end
      if posts_with_comments.any?
        # Collect all comments at once
        comments = get_comments(posts_with_comments.uniq, options)
        DaemonKit.logger.debug "FB comments => #{comments.inspect}"
        # then add comments to their posts
        posts.each do |p|
          p.comments = comments[p.id] if comments[p.id]
        end
      end
      posts
    end
    
    protected
      
    # Collects post's comments, returns results as hash of arrays, 
    # with key = post_id, value = comments
    def get_comments(post_ids, options)
      returning Hash.new do |res| 
        # Perform query to fetch commenter name with comment, sorted by time
        query = @query.comments_multi_fql(post_ids, options)
        results = @request.do_request { session.fql_multiquery(query) }
        
        if results && results.has_key?('query2')
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
end