# $Id

# Backup Desktop App User object

require 'facebooker'

module FacebookBackup
  class << self
    @@ConfigPath = DAEMON_ROOT + '/config/facebooker.yml'
    
    def load_config(path=@@ConfigPath)
      begin
        # DaemonKit support yml configuration loading - but not yet
        #DaemonKit::Config.load('facebooker')
        c = YAML.load_file(path)
        c[ENV['DAEMON_ENV']]
      rescue
        puts "Unable to load #{fb_conf_file}: $!"
        exit
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
  
  class User
    attr_reader :id, :session_key
    attr_accessor :secret_key
    
    def initialize(uid, session_key, secret_key=nil)
      @id, @session_key, @secret_key = uid, session_key, secret_key
      @session = nil
    end
    
    def login!
      session.connect(session_key, id, nil, secret_key)
    end
    
    def session
      @session ||= FacebookBackup::Session.create
    end
    
    def logged_in?
      session.secured?
    end
  end
end