# $Id$

# Need to encapsulate FQL into class now that queries has become so complex.
# FB is also constantly breaking their own API so it makes sense to keep the
# generation code separated from the User class

module FacebookBackup
  class Query
    attr_reader :id
    
    def initialize(fb_id)
      @id       = fb_id
    end
    
    # Returns photo albums multiquery hash
    def photos_multi_fql(album_id)
      photo_query = "SELECT pid, aid, owner, src, src_big, src_small, link, caption, created " +
        "FROM photo WHERE aid= '#{album_id}'"
      tag_query = "SELECT pid, text FROM photo_tag WHERE pid IN (SELECT pid FROM #query1)"
      {'query1' => photo_query, 'query2' => tag_query}
    end
    
    # Returns friends query string
    def friends_fql
      query = "SELECT uid, name, pic_square, profile_url FROM user WHERE uid IN (SELECT uid2 FROM friend WHERE uid1 = #{id})"
    end
    
    # Returns massive stream read fql
    def posts_multi_fql(options)
      build_stream_fql("(source_id = '#{id}')",
#        " OR ((filter_key IN (SELECT filter_key FROM stream_filter WHERE uid = '#{id}' AND type = 'newsfeed')) AND (actor_id = '#{id}'))" +
        # THIS ONE STRAIGHT UP DOES NOT WORK ANYMORE...
        # " OR (post_id IN (SELECT post_id FROM comment WHERE post_id IN (SELECT post_id FROM stream WHERE source_id IN (SELECT target_id FROM connection WHERE source_id='#{id}')) AND (fromid = '#{id}')))", 
        options)
    end
    
    
    # For posts user made on other walls
    def friends_wall_posts_fql(friend_id)
      # multiquery to try to fix the old super nexted query in posts_multi_fql that doesn't work now.
      # DOESN'T WORK
      #{:query1 => "SELECT post_id FROM stream WHERE (source_id IN (SELECT target_id FROM connection WHERE source_id= #{id}))",
      # :query2 => "SELECT #{stream_query_columns} FROM stream WHERE (actor_id = #{id}) AND (post_id IN (SELECT post_id FROM #query1))"
      #}
      build_stream_fql("source_id = #{friend_id} AND message != '' AND actor_id = #{id}")
    end
    
    # For comments user made on other walls - only returns original post
    def friends_wall_comments_multi_fql(options)
      {:query1 => "SELECT target_id FROM connection WHERE source_id= #{id}", 
       :query2 => "SELECT post_id FROM stream WHERE source_id IN (SELECT target_id FROM #query1) " + 
        (options[:start_at] ? " AND (created_time > #{options[:start_at]}) " : "") + 
        "ORDER BY created_time " + 
        (options[:limit] ? " LIMIT #{options[:limit]}" : ""), 
       :query3 => "SELECT post_id FROM comment WHERE post_id IN (SELECT post_id FROM #query2) AND fromid = #{id}",
       :query4 => build_stream_fql("post_id IN (SELECT post_id FROM #query3)", options)
      }
    end
    
    # Returns comments fql.  
    # Takes post ids array & options hash as input
    def comments_multi_fql(post_ids, options)
      query = build_comment_fql("post_id IN (#{post_ids.join(',')})", options)
      name_query = "SELECT uid, name, pic_square, profile_url FROM user WHERE uid IN (SELECT fromid FROM #query1)"
      {:query1 => query, :query2 => name_query}
    end
    
    # Returns like fql
    def likes_fql(object_id)
      "SELECT user_id FROM like WHERE object_id='#{object_id}'"
    end
    
    # Returns like table fql for many objects
    def all_likes_fql(object_ids)
      "SELECT object_id, user_id FROM like WHERE object_id IN (#{object_ids.join(',')})"
    end
    
    # FQL stream query fields
    def stream_query_columns
      "actor_id, post_id, target_id, created_time, updated_time, strip_tags(attribution), message, attachment, likes.count, comments.count, permalink, action_links"
    end
    
    # FQL comment query fields
    def comment_query_columns
      "post_id, fromid, time, text, username"
    end
    

    # Generate stream query
    def build_stream_fql(conditions, options={})
      query = "SELECT #{stream_query_columns} FROM stream WHERE (#{conditions})"
      query << " AND (created_time > #{options[:start_at]})" if options[:start_at]
      query << " ORDER BY created_time"
      #query << " LIMIT 400" # THIS TOTALLY FUCKED UP SOME ACCOUNTS!  DO NOT USE
      query
    end
    
    # Generate comments query 
    def build_comment_fql(conditions, options={})
      query = "SELECT #{comment_query_columns} FROM comment WHERE (#{conditions})"
      query << " AND (time > #{options[:start_at]})" if options[:start_at]
      query << " ORDER BY time"
      #query << " LIMIT 400" # THIS TOTALLY FUCKED UP SOME ACCOUNTS!  DO NOT USE
      query
    end
  end
end