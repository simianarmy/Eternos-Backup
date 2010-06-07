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
  config.log_level = :debug
  
  # Log backraces when a thread/daemon dies (Recommended)
  config.backtraces = false
  
  # Configure the safety net (see DaemonKit::Safety)
  if DaemonKit.env == 'production'
    config.safety_net.handler = :mail # (or :hoptoad )
    config.safety_net.mail.host = 'localhost'
    config.safety_net.mail.recipients = ['marc@eternos.com']
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

MAX_SIMULTANEOUS_JOBS           = 15 # Number of worker daemons forked
DISABLE_LONG_DATASETS           = false
THREADING_JOBS_ENABLED          = false # Works...but too well
FACEBOOK_ACTIVITY_SYNC_ENABLED  = false
MAX_FRIENDS_PER_POSTS_BACKUP    = 5 # For long facebook posts on walls backup
