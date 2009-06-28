# $Id

# Backup Desktop App User object

require 'active_support' # for mattr_reader
require RAILS_ROOT + '/lib/facebook_desktop'
require RAILS_ROOT + '/lib/facebook_user_profile'
require File.dirname(__FILE__) + '/facebook_photo_album'
require File.dirname(__FILE__) + '/facebook_activity'

module FacebookBackup
  
  # Wraps Facebooker::User class
  
  class User
    attr_reader :id, :session_key, :profile
    attr_accessor :secret_key
    
    def initialize(uid, session_key, secret_key=nil)
      @id, @session_key, @secret_key = uid, session_key, secret_key
      @session = nil
    end
    
    def login!
      session.connect(session_key, id, nil, secret_key)
      user
    end
    
    def session
      @session ||= FacebookDesktopApp::Session.create
    end
    
    def user
      @user ||= session.user
    end
    
    def logged_in?
      session.secured?
    end
    
    # Returns facebook (cached) profile in hash, with keys from Facebooker::User::FIELDS
    def profile
      @profile ||= FacebookUserProfile.populate(user)
    end
    
    def albums
      user.albums.collect {|a| FacebookPhotoAlbum.new(a)}
    end
    
    def photos(album, options={})
      # Multiquery for photos info + tags
      photos = []
      if options[:with_tags]
        photo_query = "SELECT pid, aid, owner, src, src_big, src_small, link, caption, created " +
          "FROM photo WHERE aid= '#{album.id}'"
        tag_query = "SELECT pid, text FROM photo_tag WHERE pid IN (SELECT pid FROM #query1)"

        multiquery = {'query1' => photo_query, 'query2' => tag_query}
        resp = session.fql_multiquery(multiquery)
        
        photos = resp['query1']
        # Format tags keyed by photo id
        tags = resp['query2'].inject({}) do |result, element| 
          (result[element['pid'].to_i] ||= []) << element['text']
          result
        end
        #puts "Tags => #{tags.inspect}"
      else
        photos = session.get_photos(nil, nil, album.id)
      end
      # We could just return photos and let the client convert them if we wanted to be
      # all general-purpose and all, but YAGNI, right?
      photos.map do |p|
        photo = FacebookPhoto.new(p)
        # If tags, find tags for the photo and collect into array
        photo.tags = tags[p.id] if tags
        photo
      end
    end
    
    def photo_tags(pids)
      query =<<-FQL
        SELECT pid, text FROM photo_tag WHERE pid IN (#{pids.map {|p| "'#{p}'"}.join(',')})
      FQL
      puts "Tag query #{query}"
      session.fql_query(query) do |something|
        puts something.inspect
      end
    end
    
    def friends
      #user.friends!(:name).map(&:name)
      # Use FQL for faster query
      query = "SELECT name FROM user WHERE uid IN (SELECT uid2 FROM friend WHERE uid1 = #{id})"
      session.fql_query(query).map(&:name)
    end
    
    def groups
      user.groups.map(&:group_type).reject {|g| g == 'Facebook'}
    end
    
    # Returns array of hash results
    # Only returns posts coming from this user
    def wall_posts(options={})
      query = 'SELECT actor_id, created_time, updated_time, message, attachment FROM stream WHERE source_id = ' + id.to_s
      query << " AND created_time > #{options[:start_at]}" if options[:start_at]
      query << " ORDER BY created_time"
      puts "User status updates query: #{query}"
      session.fql_query(query).reject {|p| p['actor_id'] != id.to_s}.collect {|p| FacebookActivity.new(p) }
    end
  end
end