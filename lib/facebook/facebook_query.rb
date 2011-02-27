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
      photo_query = "SELECT #{photo_table_columns.join(',')} " <<
        "FROM photo WHERE aid= '#{album_id}'"
      tag_query = "SELECT pid, text FROM photo_tag WHERE pid IN (SELECT pid FROM #query1)"
      {'query1' => photo_query, 'query2' => tag_query}
    end
    
    # Returns friends query string
    def friends_fql
      query = "SELECT uid, name, pic_square, profile_url FROM user WHERE uid IN (SELECT uid2 FROM friend WHERE uid1 = #{id})"
    end
    
    # Returns stream read fql for some source
    def posts_multi_fql(options)
      build_stream_fql("(source_id = '#{id}')",
#        " OR ((filter_key IN (SELECT filter_key FROM stream_filter WHERE uid = '#{id}' AND type = 'newsfeed')) AND (actor_id = '#{id}'))" +
        # THIS ONE STRAIGHT UP DOES NOT WORK ANYMORE...
        # " OR (post_id IN (SELECT post_id FROM comment WHERE post_id IN (SELECT post_id FROM stream WHERE source_id IN (SELECT target_id FROM connection WHERE source_id='#{id}')) AND (fromid = '#{id}')))", 
        options)
    end
    
    def page_stream_posts_fql(page_id, options)
      build_stream_fql("source_id = '#{page_id}'", options)
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
        (options[:limit] ? " LIMIT 1,#{options[:limit]}" : ""), 
       :query3 => "SELECT post_id FROM comment WHERE post_id IN (SELECT post_id FROM #query2) AND fromid = #{id}",
       :query4 => build_stream_fql("post_id IN (SELECT post_id FROM #query3)", options)
      }
    end
    
    # Returns comments fql.  
    # If type = post,
    #   comments fql for posts
    # If type = object
    #   comments fql for commented-on objects (for videos, notes, links, photos, albums)
    # Takes ids array & options hash
    def comments_multi_fql(ids, type, options)
      # Determine index column to use.  For posts or objects
      col = (type.to_sym == :post) ? 'post_id' : 'object_id'
      query = build_comment_fql("#{col} IN (#{ids.join(',')})", options)
      name_query = "SELECT uid, name, pic_square, profile_url FROM user WHERE uid IN (SELECT fromid FROM #query1)"
      {:query1 => query, :query2 => name_query}
    end
    
    # Returns like fql
    def likes_fql(object_id)
      "SELECT user_id FROM like WHERE object_id='#{object_id}'"
    end
    
    # Returns like table fql for many objects
    def all_likes_fql(object_ids)
      "SELECT object_id, user_id FROM like WHERE post_id IN (#{object_ids.join(',')})"
    end
    
    def pages_admined_fql
      "SELECT #{page_table_columns} FROM page WHERE page_id IN (SELECT page_id FROM page_admin WHERE uid = #{id})"
    end
    
    def mailboxes_fql
      "SELECT folder_id, name, unread_count FROM mailbox_folder WHERE 1"
    end
    
    def threads_fql(folder_id, options={})
      "SELECT #{thread_table_columns} FROM thread WHERE folder_id = #{folder_id}"
    end
    
    def messages_fql(thread_id, options={})
      "SELECT #{message_table_columns} FROM message WHERE thread_id = #{thread_id}"
    end
    
    def messages_multi_fql(folder_id, options={})
      {:query1 => threads_fql(folder_id, options),
       :query2 => "SELECT #{message_table_columns} FROM message WHERE thread_id IN (SELECT thread_id FROM #query1)"
      }
    end
    
    def photo_table_columns
      %W( pid aid owner src src_big src_small link caption created object_id )
    end
    
    # FQL stream table query fields
    def stream_query_columns
      "actor_id, post_id, target_id, created_time, updated_time, strip_tags(attribution), message, attachment, likes.count, comments.count, permalink, action_links"
      #"post_id"
    end
    
    # FQL comment table query fields
    def comment_query_columns
      "post_id, object_id, fromid, time, text, username"
    end
    
    def thread_table_columns
      "thread_id, folder_id, subject, recipients, updated_time, parent_message_id, parent_thread_id, message_count, snippet, snippet_author, object_id, unread, viewer_id"
    end
    
    def message_table_columns
      "message_id, thread_id, author_id, body, created_time, attachment"
    end
    
    def page_table_columns
      "page_id, name, pic_big, page_url, fan_count, type, website, founded, company_overview, mission, products, location, parking, public_transit, hours"
    end
    
    # Generate stream query
    def build_stream_fql(conditions, options={})
      query = "SELECT #{stream_query_columns} FROM stream WHERE (#{conditions})"
      query << " AND (updated_time >= #{options[:start_at]})" if options[:start_at]
      query << " AND (updated_time <= #{options[:end_at]})" if options[:end_at]
      query << " LIMIT 0, 100" if options[:limit]
      #query << " ORDER BY created_time"
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