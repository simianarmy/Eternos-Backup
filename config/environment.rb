# Be sure to restart your daemon when you modify this file

# Uncomment below to force your daemon into production mode
#ENV['DAEMON_ENV'] ||= 'production'

# Boot up

# mysqlplus must be required before mysql in order to be used
#require 'rubygems'
#require 'mysqlplus-0.1.2/lib/mysqlplus'

# THE PROBLEM BELOW WAS SUPPOSED TO BE FIXED IN RAILS 2.3+
# Ordering required for json & activesupport to work together.
# json before activesupport = 
#  the dreaded TypeError: wrong argument type Hash (expected Data) error
# http://blog.swivel.com/code/2009/03/index.html
#require 'active_support'
#require 'json'

# Load required gems using Bundler
require File.join(File.dirname(__FILE__), 'boot')

# DAEMON-KIT MODULE-NAME CONFLICT FIX!
# REQUEST FIX IN FORUMS!
# Add Rails gem directory to head of load path to prevent initializer file conflict bug!
$LOAD_PATH.unshift "/opt/ruby-enterprise/lib/ruby/gems/1.8/gems/rails-2.3.4/lib"
$LOAD_PATH.unshift "/data/EternosBackup/shared/bundle/ruby/1.8/gems/rails-2.3.4/lib"

DaemonKit::Initializer.run do |config|
  # Uncomment to allow mutiple instances to run
  # config.mulitple = true
  # Force the daemon to be killed after X seconds from asking it to
  # config.force_kill_wait = 30
  
  # Set DAEMON_NAME in bin/ files
  # All this crazyiness is all for god monitoring to work properly...consider using Monit
  daemon_name = (defined?(DAEMON_NAME) && (DAEMON_NAME != 'backupd')) ? 'backupd-'+DAEMON_NAME : 'backupd'

  config.daemon_name = daemon_name
  config.log_path = DAEMON_ROOT + "/log/#{daemon_name}.log"
  config.log_level = :info
  
  # Log backraces when a thread/daemon dies (Recommended)
  config.backtraces = false
  
  # Configure the safety net (see DaemonKit::Safety)
  if DaemonKit.env == 'production'
    config.safety_net.handler = :mail # (or :hoptoad )
    # Not supported in newer version of gem
    #config.safety_net.mail.host = 'localhost'
    #config.safety_net.mail.recipients = ['marc@eternos.com']
  end
end


def get_rails_path(dir)
  (dir[0].chr == '/') ? dir : File.expand_path(File.dirname(__FILE__)) + '/' + dir
end

rails_config = DaemonKit::Config.load('rails')

RAILS_ROOT =  get_rails_path(rails_config['rails_root'])
$: << RAILS_ROOT

# Get shared configuration directory, b/c rails_root expands 'current' directory symlink, 
# which means files relative to RAILS_ROOT might not be accessible after cap deploys
RAILS_SHARED_CONFIG_DIR = get_rails_path(rails_config['rails_config_dir'])

# Backup job control settings

MAX_SIMULTANEOUS_JOBS           = 10 # Number of simultaneous EM workers 
DISABLE_LONG_DATASETS           = false
THREADING_JOBS_ENABLED          = false # Works...but too well
FACEBOOK_ACTIVITY_SYNC_ENABLED  = true
MAX_FRIENDS_PER_POSTS_BACKUP    = 100 # For long facebook posts on walls backup
MAX_FRIENDS_PER_BACKUP          = MAX_FRIENDS_PER_POSTS_BACKUP # Any more and jobs cause others to hang
PURGE_QUEUE_FILE                = 'flush_queues.txt'
