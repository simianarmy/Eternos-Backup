# Module for Facebook's OpengGraph API

require "benchmark"

module FacebookBackup::OpenGraph
  # Wraps Facebooker::User class
  class User < FacebookBackup::User
    attr_reader :auth_token, :profile, :client
    
    def initialize(uid, auth_token, app)
      @auth_token, @app = auth_token, app
      @fb_app   = FacebookBackup::OpenGraphApp.new(app)
      @client   = nil
      @user     = nil
      @query    = FacebookBackup::Query.new(uid)
      super(uid)
    end
    
    def login!
      @client = @fb_app.session(@auth_token)
    end
    
    def user
      @user ||= @request.do_request { @fb_app.user }
    end
    
    def logged_in?
      user && @request.do_request { @fb_app.verify_permissions }
    end
    
    def profile
      returning(Hash.new) do |data|
        @request.do_request do
          # Get profile attributes.
          # TODO: Use real-time updates subscription!
          FacebookUserProfile::OpenGraphFields.each do |attr| 
            data[attr] = FacebookBackup::OpenGraphApp.user_profile_value(user, attr)
          end
          # Save associations too
          FacebookUserProfile::OpenGraphAssociations.each do |attr| 
            data[attr] = FacebookBackup::OpenGraphApp.user_profile_value(user, attr)
          end
          DaemonKit.logger.debug "PROFILE DATA = #{data.inspect}"
        end
      end
    end
    
    # Memoized user friends request, returns array of {:id, :name} hashes
    def friends
      # Use FQL for faster query
      @friends ||= @request.do_request { user.friends }
      @friends ||= []
    end
    
    # Memoized
    def sorted_friend_ids
      @sorted_friends ||= friends.map(&:id).sort
    end
    
    # Lookup friend hash by id
    def friend(uid)
      friends.detect {|f| f.id.to_i == uid.to_i}
    end
    
    def groups
      @request.do_request { user.groups } || []
    end
    
    # Returns array of Hashie::Mash objects representing Facebook Page info
    def administered_pages
      @request.do_request do
        if res = client.fql_query(@query.pages_admined_fql) 
          DaemonKit.logger.debug "PAGES = #{res.inspect}"
          # Convert array of hashes to hashie objects
          res.parsed_response.map {|r| Hashie::Mash.new(r) }
        end
      end
    end
    
    # Get all posts on pages user administers
    def get_page_posts(page_id, options={})
      posts = @request.do_request {
        query = @query.page_stream_posts_fql(page_id, options)
        DaemonKit.logger.debug "PAGE POSTS FQL: #{query}"
        client.fql_query query
      }
      DaemonKit.logger.debug "Got posts: #{posts.inspect}"
      if posts
        parse_posts posts, options
      end
    end
    
    def albums
      if albums = @request.do_request { @user.albums }
        albums.map{|a| FacebookProxyObjects::OpenGraph::PhotoAlbum.new(a)}
      else
        []
      end
    end
    
    # Returns all photos in an album, with optional tags & comments
    def photos(album, options={})
      # Multiquery for photos info + tags
      photos = []
      tags = nil
      comments = nil
      
      photos = @request.do_request { client.get_and_map "#{album.id}/photos" }
      DaemonKit.logger.debug "PHOTOS BEFORE: #{photos.inspect}"
      # OpenGraph results already have comments & tags assigned to each photo
      res = photos.map do |p| 
        ogp = FacebookProxyObjects::OpenGraph::Photo.new(p)
      end
      DaemonKit.logger.debug "PHOTOS AFTER: #{res.inspect}"
      res
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
          client.fql_query @query.posts_fql(options)
        rescue Exception => e
          # If we get a resource limit error, try with reduced range query
          DaemonKit.logger.info "Exception in facebook worker get_posts:posts_fql: #{e.class} #{e.message}"
          unless retries >= max_retries
            if @request.retry_from_error?(e)
              retries += 1
              DaemonKit.logger.info "Retry post ##{retries}"
              options[:start_at] = 2.weeks.ago.to_i
              sleep(2)
              retry
            end
          end
          DaemonKit.logger.info "Unable to fetch posts_fql!"
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
          client.fql_multiquery(@query.friends_wall_comments_multi_fql(options))
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
                  client.fql_query(@query.friends_wall_posts_fql(uid))
                }
                if response && response.is_a?(Array)
                  #DaemonKit.logger.debug "FRIEND'S WALL POSTS: #{response.inspect}"
                  res += response
                  # Save friend id as last processed for this user
                  @redis.set last_friend_processed_key_name, uid.to_s
                  # Increase processed counter
                  total_processed = @redis.incr friends_processed_counter_key_name
                else
                  DaemonKit.logger.warn "Invalid response from FQL!"
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
    
    ####################
    # Messages methods
    ####################
    
    def threads(options={})
      # Get list of 'folders'
      threads = []
      mboxes = get_mailboxes(options) || []
      mboxes.each do |folder|
        @request.do_request {
          threads += client.fql_query(@query.threads_fql(folder['folder_id'], options))
        }
      end
      # Convert threads to Facebooker::Thread objects
      threads.compact.map{|t| Facebooker::MessageThread.new(t) }.map { |t|
        FacebookProxyObjects::Rest::FacebookMessageThread.new(t)
      }
    end
    
    # Retrieves all messages for a thread
    # Takes Facebooker::MessageThread object
    # Returns thread object with messages assigned
    def messages(thread, options={})  
      messages = @request.do_request {
        client.fql_query(@query.messages_fql(thread.id, options))        
      }
      DaemonKit.logger.debug "Got thread messages: #{messages.inspect}"
      thread.messages = messages if messages
      thread
    end
    
    protected
      
    # Parse wall post queries (from user's stream or friends' walls)
    def parse_posts(res, options={})
      # Only keep user's posts if option on
      posts = res.reject { |post|
        (post['actor_id'].to_s != id.to_s) && options[:user_posts_only]
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
        results = @request.do_request { client.fql_multiquery(query) }
        
        # Parse multiquery response
        if results && results['query1'] && results['query2']
          # Build userid => user map
          uid_map = results['query2'].inject({}) {|h, user| h[user['uid'].to_s] = user; h}
          comment_id_attr = (source_type == :post) ? :post_id : :object_id
          
          # Build comments from comment table query results
          results['query1'].each_with_index do |comment, i|
            fb_comment = FacebookBackup::FacebookComment.new(comment)

            if fb_comment.username.blank? && uid_map[fb_comment.fromid.to_s]
              fb_comment.user = Hashie::Mash.new(uid_map[fb_comment.fromid.to_s])
            end
            (res[fb_comment[comment_id_attr]] ||= []) << fb_comment
          end
          DaemonKit.logger.debug "PARSED COMMENTS: #{res.inspect}"
        end
      end
    end
    
    # Query like table for multiple objects.  Returns hash of object => user ids
    def get_all_likes(objects)
      returning Hash.new do |res|
        if results = @request.do_request { client.fql_query(@query.all_likes_fql(objects)) }
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
      results = @request.do_request { client.fql_query(@query.likes_fql(object_id)) }
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
    
    def get_mailboxes(options={})
      @request.do_request { 
        client.fql_query(@query.mailboxes_fql)
      }
    end
    
  end
end