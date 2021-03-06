# $Id

# Backup Desktop App User object

#require 'active_support' # for mattr_reader
require RAILS_ROOT + '/lib/facebook_backup'

require File.dirname(__FILE__) + '/facebook_activity'
require File.dirname(__FILE__) + '/facebook_query'
require File.dirname(__FILE__) + '/facebook_request'
require File.dirname(__FILE__) + '/../request_scheduler'
require 'benchmark'
require 'redis'

module FacebookBackup
  # FacebookComment
  # Helper class to store comment data with author attributes
  class FacebookComment < Hashie::Mash
    def user=(fb_user)
      self.username     = fb_user.name
      self.user_pic     = fb_user.pic_square
      self.profile_url  = fb_user.profile_url
    end

    # Returns commenter user data in hash format for external use
    def user_data
      {:username => self.username,
        :pic_url => self.user_pic,
        :profile_url => self.profile_url
      }
    end
  end
  
  # Wraps Facebooker::User class
  class User    
    @@friend_post_query_group_size  = 10
    @@friend_post_query_sleep_time  = 60
    @@delayPerAPIRequest            = 1 # in seconds
    
    attr_reader :id, :session_key, :profile
    attr_accessor :secret_key
    
    delegate :name, :to => :user
    
    def initialize(uid, session_key, secret_key=nil)
      @id, @session_key, @secret_key = uid, session_key, secret_key
      @session = nil
      @facebook_desktop_config = File.join(RAILS_SHARED_CONFIG_DIR, 'facebooker_desktop.yml')
      @query = FacebookBackup::Query.new(@id)
      @redis = ::BackupWorker.cache.cache
      set_api_request_delay(@@delayPerAPIRequest)
    end
    
    # Creates new FacebookBackup::Request object using scheduler based on seconds arg
    # Will overwrite any existing instance of the @request object
    def set_api_request_delay(seconds=0)
      DaemonKit.logger.debug "Setting FB api scheduler with #{seconds} sec. delay"
      scheduler = RequestScheduler::ThreadSafe.new('FacebookBackup', :delay => seconds)
      @request = FacebookBackup::Request.new(@id, scheduler)
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
      @request.do_request { session.verify_permissions }
    end
    
    # Returns facebook (cached) profile in hash, with keys from Facebooker::User::FIELDS
    def profile
      @profile ||= @request.do_request { FacebookUserProfile.populate(user) }
    end
    
    def albums
      albums = @request.do_request { user.albums.collect {|a| FacebookProxyObjects::FacebookPhotoAlbum.new(a)} }
      albums || []
    end
    
    # Returns all photos in an album, with optional tags & comments
    def photos(album, options={})
      # Multiquery for photos info + tags
      photos = []
      tags = nil
      comments = nil
      
      if options[:with_tags]
        if resp = @request.do_request { session.fql_multiquery(@query.photos_multi_fql(album.id)) }
          photos = resp['query1']
          # Format tags keyed by photo id
          tags = resp['query2'].inject({}) do |result, element| 
            (result[element['pid'].to_i] ||= []) << element['text']
            result
          end
          # Fetch photos' comments
          comments = get_comments(photos.map{|p| p.object_id}.uniq, :object, options)
          DaemonKit.logger.debug "PHOTO COMMENTS = #{comments.inspect}"
        end
      else
        photos = @request.do_request { session.get_photos(nil, nil, album.id) }
      end

      # We could just return photos and let the client convert them if we wanted to be
      # all general-purpose and all, but YAGNI, right?
      photos.map do |p|
        photo = FacebookProxyObjects::FacebookPhoto.new(p)
        # If tags, find tags for the photo and collect into array
        photo.tags = tags[p.id] if tags && tags[p.id]
        # If comments for this photo, save them to object
        photo.comments = comments[p.object_id]  if comments && comments[p.object_id]
        DaemonKit.logger.debug "FacebookPhoto = #{photo.inspect}"
        photo
      end
    end
    
    # Returns all comments on photos in an album
    def photo_comments(album, options={})
    end
    
    # Memoized
    def friends
      # Use FQL for faster query
      @friends ||= @request.do_request { session.fql_query(@query.friends_fql) }
      @friends ||= []
    end
    
    # Memoized
    def sorted_friend_ids
      @sorted_friends ||= friends.map(&:uid).sort
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
    
    def administered_pages
      res = @request.do_request { session.fql_query(@query.pages_admined_fql) }
    end
    
    # Returns array of FacebookActivity objects
    # Includes:
    # => posts on this user's wall & user comments with threads
    # Options:
    # => start_at: unixtime - minimum created_time value
    # => user_posts_only: boolean - set to true if only user-created posts should be included
    def get_posts(options={})
      # Retrieve wall posts & posts made on other pages
      res = @request.do_request {
        max_retries = 3
        retries = 0
        begin
          session.fql_query @query.posts_multi_fql(options)
        rescue Exception => e
          # If we get a resource limit error, try with reduced range query
          DaemonKit.logger.info "Exception in facebook worker get_posts:posts_multi_fql: #{e.class} #{e.message}"
          unless retries >= max_retries
            if @request.retry_from_error?(e)
              retries += 1
              DaemonKit.logger.info "Retry post ##{retries}"
              options[:start_at] = 2.weeks.ago.to_i
              sleep(2)
              retry
            end
          end
          DaemonKit.logger.info "Unable to fetch posts_multi_fql!"
          raise e
        end
      }
      if res
        parse_posts res, options
      end
    end
    
    # This method is for finding comments on posts on other walls
    def get_post_comments(options={})
      response = @request.do_request {
        max_retries = 3
        retries = 0
        begin
          session.fql_multiquery(@query.friends_wall_comments_multi_fql(options))
        rescue Exception => e
          DaemonKit.logger.info "Exception in facebook worker get_posts:friends_wall_comments_multi_fql: #{e.class} #{e.message}"
          # If we get a resource limit error, try with reduced range query
          unless retries >= max_retries
            if @request.retry_from_error?(e)
              retries += 1
              DaemonKit.logger.info "Retry post ##{retries}"
              options[:limit] = 100
              options[:start_at] = 2.weeks.ago.to_i
              sleep(2)
              retry
            end
          end
          DaemonKit.logger.info "Unable to fetch friends_wall_comments_multi_fql!"
          raise e
        end
      }
      if response && response['query4']
        parse_posts response['query4'], options
      end
    end
    
    # Get all posts on pages user administers
    def get_page_posts(page_id, options={})
      posts = @request.do_request {
        session.fql_query @query.page_stream_posts_fql(page_id, options)
      }
      if posts
        parse_posts posts, options
      end
    end
    
    # Get posts user made on friends' walls.
    # SHOULD BE EXECUTED AS LITTLE AS POSSIBLE IN ORDER TO MINIMIZE TOTAL NUMBER OF 
    # API REQUESTS.
    # API calls = (# Users) x AVG # FRIENDS PER USER
    def get_posts_to_friends(options={})
      # This is for finding posts the user made on other walls.
      # Need to rate limit to 1 per 6 secs. or 100 per 600
      idx = 0
      
      # Only do MAX_CONSECUTIVE_FRIENDS at a time so that we don't fill up 
      # the worker queues processing users with thousands of friends.
      # We will store the most recent friend processed in the Redis cache 
      # so that next time job runs it will start at the next friend.
      unless friends_batch = get_next_friends_batch
        DaemonKit.logger.info "No friends to process for user #{id}"
        return true # Same as if all friends processed
      end
      batch_count = friends_batch.size
      friend_count = friends.size
      last_friend_processed = nil
      total_processed = 0
      query_time = 0
      idx = 0
      
      friends_batch.in_groups_of(@@friend_post_query_group_size).each do |group|
      #EM::Iterator.new(friends_batch).each do |uid, iter|
          res = []
          query_time = 0
    
          group.each do |uid|
            break unless uid # end of friends list reached
            idx += 1
            begin
              DaemonKit.logger.info "Fetching posts to friend #{uid} - #{idx} of #{batch_count} (#{friend_count} total)..."
              query_time += Benchmark.realtime do
                response = @request.do_request { 
                  session.fql_query(@query.friends_wall_posts_fql(uid))
                }
                if response && response.is_a?(Array)
                  res += response
                  # Save friend id as last processed for this user
                  @redis.set last_friend_processed_key_name, uid.to_s
                  # Increase processed counter
                  total_processed = @redis.incr friends_processed_counter_key_name
                end
              end
              last_friend_processed = uid
            # DON'T CHOKE ON RANDOM FACEBOOK NETWORK CRAP
            rescue FacebookBackup::Request::FacebookNetworkError => e
              DaemonKit.logger.warn e.to_s
            end
          end # group.each
          
          # Yield results to caller so they can write intermediate results to db
          # in case they have hundreds of friends.  High probability of facebook 
          # network failure forces this Emacs auto-save feature.
          yield parse_posts(res, options)
        
          # Sleep to keep FB api rate limit under max
          if idx > 0 && ((idx % @@friend_post_query_group_size) == 0) && 
            (idx != MAX_FRIENDS_PER_POSTS_BACKUP) &&
            (sleep_time = @@friend_post_query_sleep_time - query_time) > 0

            DaemonKit.logger.info "Should sleep for #{sleep_time} seconds..."
            # IT'S NOT RECOMMENDED TO USE sleep() WITH EVENTMACHINE PROGRAMMING.
            # IT MAY BE BETTER TO PARRALELIZE REQUESTS USING EM::Iterator...
            # SOMETHING IS CAUSING redis TO DEADLOCK ON READS..COULD THIS BE WHY??  
            #sleep(sleep_time)
          end
      end # friends_batch.in_group_of().each
      
      # Wait for all worker threads
      #workers.each {|w| w.join}
      
      # Returns TRUE only if we processed the last friend in the list
      if finished_job = last_friend_processed && (last_friend_processed == sorted_friend_ids.last)
        DaemonKit.logger.debug "Finished processing all friends!"
      # OR if we reached our processing limit
      elsif total_processed >= MAX_FRIENDS_PER_BACKUP
        DaemonKit.logger.debug "Max friends per backup reached!"
        finished_job = true
      end
      # Reset internal job counter when finished
      if finished_job
        @redis.set friends_processed_counter_key_name, 0
      end
      finished_job
    end
    
    protected
      
    # Parse wall post queries (from user's stream or friends' walls)
    def parse_posts(res, options={})
      # Only keep user's posts if option on
      posts = res.reject { |post|
        #DaemonKit.logger.debug "Got post: #{post.inspect}" 
        (post['actor_id'] != id.to_s) && options[:user_posts_only]
      }
      # Collect facebook response into FacebookActivity collection
      posts.map! { |act| FacebookActivity.new(act) }
      
      unless posts
        DaemonKit.logger.error "Facebook Backup: Unable to fetch posts array for #{id}"
        return []
      end

      # post-process results
      posts.uniq!
      posts_with_comments = []
      liked_objects = []
      
      posts.each do |p|
        #DaemonKit.logger.debug p.inspect, "\n"
        # Add author name if author != user
        p.author = friend_name(p.author_id) if p.author_id != id.to_s
        
        # Get all comments & likes
        posts_with_comments << "'#{p.id}'" if p.has_comments?
        liked_objects << "'#{p.id}'" if p.has_likers?
      end
      if posts_with_comments.any?
        # Collect all comments at once
        comments = get_comments(posts_with_comments.uniq, :post, options)
       
        # then add comments to their posts
        posts.each do |p|
          p.comments = comments[p.id] 
        end
      end
      if liked_objects.any?
        DaemonKit.logger.debug "Liked objects: #{liked_objects.inspect}"
        # Collect names of anyone who 'liked' this post
        likers = get_all_likes(liked_objects.uniq)
        DaemonKit.logger.debug "Got likes: #{likers.inspect}"
        # then add likers to their posts
        posts.each do |p|
          p.likers = likers[p.object_id] if p.has_likers?
        end
      end
      posts
    end
    
    # Collects posts' or objects' comments
    # Returns results as hash
    #   key = post_id/object_id &
    #   value = array of FacebookBackup::FacebookComment objects
    # Arguments:
    # => ids: array of Facebook post ids or object ids
    # => source_type: one of [post | object]
    # => options: options hash
    def get_comments(ids, source_type, options)
      returning Hash.new do |res| 
        # Perform query to fetch commenter name with comment, sorted by time
        query = @query.comments_multi_fql(ids, source_type, options)
        results = @request.do_request { session.fql_multiquery(query) }
        
        if results && results.has_key?('query2')
          # Build userid => user map
          uid_map = results['query2'].inject({}) {|h, user| h[user.id.to_s] = user; h}
          comment_id_attr = (source_type == :post) ? :post_id : :object_id
          
          results['query1'].each_with_index do |comment, i|
            fb_comment = FacebookBackup::FacebookComment.new(comment)

            if fb_comment.username.blank? && uid_map[fb_comment.fromid]
              fb_comment.user = uid_map[fb_comment.fromid]
            end
            (res[fb_comment[comment_id_attr]] ||= []) << fb_comment
          end
        end
      end
    end
    
    # Query like table for multiple objects.  Returns hash of object => user ids
    def get_all_likes(objects)
      returning Hash.new do |res|
        if results = @request.do_request { session.fql_query(@query.all_likes_fql(objects)) }
          results.each do |result|
            friend_name = (result['user_id'] == id.to_s) ? user.name : (friend(result['user_id']).name rescue nil)
            (res[result['object_id']] ||= []) << friend_name
          end
        end
      end
    end
    
    # Query like table for some object (video, note, link, photo, or photo album).
    # Returns array of name strings if any found
    def get_likers(object_id)
      results = @request.do_request { session.fql_query(@query.likes_fql(object_id)) }
      if results 
        results.map! do |res| 
          if res['user_id'] == id.to_s
            user.name
          else
            friend(res['user_id']).name rescue nil
          end
        end
        results.compact
      end
    end
    
    # Return next N friends to process
    def get_next_friends_batch
      # Get all friends & sort by their user IDs.
      DaemonKit.logger.debug "All friends: #{sorted_friend_ids.inspect}"
      
      # Check Redis for last friend processed
      idx = 0
      if last_friend = @redis.get(last_friend_processed_key_name)
        DaemonKit.logger.debug "Got value from Redis cache: #{last_friend}"
        # If last processed friend found, start at the next index
        if idx = sorted_friend_ids.index(last_friend.to_i)
          idx += 1
        else
          idx = 0
        end
      end
      idx = 0 if idx >= (sorted_friend_ids.size - 1)
      
      DaemonKit.logger.debug "Returning friends from index #{idx}"
      # Return at most MAX_FRIENDS_PER_POSTS_BACKUP friends - don't wrap for now
      sorted_friend_ids.slice(idx, MAX_FRIENDS_PER_POSTS_BACKUP)
    end
    
    def last_friend_processed_key_name
      "last-friend_#{id}"
    end
    
    def friends_processed_counter_key_name
      "#{id}:FB-friends-processed"
    end
  end
end