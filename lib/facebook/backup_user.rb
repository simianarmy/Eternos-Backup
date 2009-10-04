# $Id

# Backup Desktop App User object

#require 'active_support' # for mattr_reader
require RAILS_ROOT + '/lib/facebook_desktop'
require RAILS_ROOT + '/lib/facebook_user_profile'
require RAILS_ROOT + '/lib/facebook_photo_album'
require File.dirname(__FILE__) + '/facebook_activity'
require File.dirname(__FILE__) + '/../request_scheduler'

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
      @user ||= @scheduler.execute { session.user }
    end
    
    def logged_in?
      @scheduler.execute { session.verify }
    end
    
    # Returns facebook (cached) profile in hash, with keys from Facebooker::User::FIELDS
    def profile
      @profile ||= @scheduler.execute { FacebookUserProfile.populate(user) }
    end
    
    def albums
      @scheduler.execute { user.albums.collect {|a| FacebookPhotoAlbum.new(a)} }
    end
    
    def photos(album, options={})
      # Multiquery for photos info + tags
      photos = []
      if options[:with_tags]
        photo_query = "SELECT pid, aid, owner, src, src_big, src_small, link, caption, created " +
          "FROM photo WHERE aid= '#{album.id}'"
        tag_query = "SELECT pid, text FROM photo_tag WHERE pid IN (SELECT pid FROM #query1)"

        multiquery = {'query1' => photo_query, 'query2' => tag_query}
        resp = @scheduler.execute { session.fql_multiquery(multiquery) }
        
        photos = resp['query1']
        # Format tags keyed by photo id
        tags = resp['query2'].inject({}) do |result, element| 
          (result[element['pid'].to_i] ||= []) << element['text']
          result
        end
      else
        photos = @scheduler.execute { session.get_photos(nil, nil, album.id) }
      end
      # We could just return photos and let the client convert them if we wanted to be
      # all general-purpose and all, but YAGNI, right?
      photos.map do |p|
        #puts "Photo => #{p.inspect}"
        photo = FacebookPhoto.new(p)
        # If tags, find tags for the photo and collect into array
        photo.tags = tags[p.id] if tags
        photo
      end
    end
    
    # Memoized
    def friends
      #user.friends!(:name).map(&:name)
      # Use FQL for faster query
      query = "SELECT uid, name FROM user WHERE uid IN (SELECT uid2 FROM friend WHERE uid1 = #{id})"
      @friends ||= @scheduler.execute { session.fql_query(query) }
    end
    
    def friend_name(uid)
      friends.detect {|f| f.uid == uid.to_i}.name rescue nil
    end
    
    def groups
      @scheduler.execute { user.groups.map(&:group_type).reject {|g| g == 'Facebook'} }
    end
    
    # Returns array of hash results
    # Only returns posts coming from this user & comments
    # Options:
    # => start_at: unixtime - minimum created_time value
    # => user_posts_only: boolean - set to true if only user-created posts should be included
    
    def wall_posts(options={})
      query = 'SELECT actor_id, created_time, updated_time, message, attachment FROM stream WHERE source_id = ' + id.to_s
      query << " AND created_time > #{options[:start_at]}" if options[:start_at]
      query << " ORDER BY created_time"
      
      @scheduler.execute do
        session.fql_query(query).reject {|p| (p['actor_id'] != id.to_s) && options[:user_posts_only]}.collect {|p| FacebookActivity.new(p) }
      end
    end
  end
end