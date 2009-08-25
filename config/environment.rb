# Be sure to restart your daemon when you modify this file

# Uncomment below to force your daemon into production mode
#ENV['DAEMON_ENV'] ||= 'production'

# Boot up
$: << File.expand_path(File.dirname(__FILE__) + '/../vendor/daemon_kit')
#$: << File.expand_path(File.dirname(__FILE__) + '/../vendor/facebooker-1.0.31-patched/lib')

require File.join(File.dirname(__FILE__), 'boot')

DaemonKit::Initializer.run do |config|

  # The name of the daemon as reported by process monitoring tools
  config.daemon_name = 'backupd'
  config.log_path = DAEMON_ROOT + '/log/backupd.log'
  
  # Uncomment to allow multiple instances to run
  # config.mulitple = true

  # Force the daemon to be killed after X seconds from asking it to
  # config.force_kill_wait = 30

  # Configure the safety net (see DaemonKit::Safety)
  # This doesn't work yet...
  # config.safety_net.handler = :mail # (or :hoptoad )
  # config.safety_net.mail.recipients = ['marc@eternos.com']
end

def get_rails_path(dir)
  (dir[0].chr == '/') ? dir : File.expand_path(File.dirname(__FILE__)) + '/' + dir
end

rails_config = DaemonKit::Config.load('rails')

RAILS_ROOT =  get_rails_path(rails_config['rails_root'])
# Get shared configuration directory, b/c rails_root expands 'current' directory symlink, 
# which means files relative to RAILS_ROOT might not be accessible after cap deploys
RAILS_SHARED_CONFIG_DIR = get_rails_path(rails_config['rails_config_dir'])
