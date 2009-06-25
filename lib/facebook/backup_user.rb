# $Id

# Backup Desktop App User object

require RAILS_ROOT + '/lib/facebook_user_profile'
require File.dirname(__FILE__) + '/facebook_photo_album'
require File.dirname(__FILE__) + '/facebook_activity'

module FacebookBackup
  class << self
    @@ConfigPath = DAEMON_ROOT + '/config/facebooker.yml'
    
    def load_config(path=@@ConfigPath)
      begin
        # DaemonKit support yml configuration loading - but not yet
        #DaemonKit::Config.load('facebooker')
        #puts "Loading facebook config: #{path}"
        c = YAML.load_file(path)
        c[ENV['DAEMON_ENV']]
      rescue Exception => e
        puts "Unable to load #{path}: #{e.to_s}"
      end
    end
  end
  
  class Session < Facebooker::Session::Desktop
    attr_reader :config
    
    def self.create(config=nil)
      @config = config || FacebookBackup.load_config
      Facebooker::apply_configuration(@config)
      super( @config['api_key'] , @config['secret_key'] )
    end
    
    def connect(session, uid, timeout, secret)
      secure_with!(session, uid, timeout, secret)
    end
  end
  
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
      @session ||= FacebookBackup::Session.create
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
      session.get_photos(nil, nil, album.id).collect do |p| 
        photo = FacebookPhoto.new(p)
        # Fetching tags adds a non-trivial amount of time - this should be 
        # only be done if option calls for it
        photo.tags = session.get_tags(p.pid) if options[:with_tags]
        photo
      end
    end
    
    def photo_tag(photo)
      session.get_tags(photo.pid)
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
      query << " AND created_time >= #{options[:start_at]}" if options[:start_at]
      query << " ORDER BY created_time"
      puts "User status updates query: #{query}"
      session.fql_query(query).reject {|p| p['actor_id'] != id.to_s}.collect {|p| FacebookActivity.new(p) }
    end
  end
end