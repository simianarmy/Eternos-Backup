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

rails_dir = DaemonKit::Config.load('rails')['rails_root']
RAILS_ROOT =  (rails_dir[0].chr == '/') ? rails_dir : File.expand_path(File.dirname(__FILE__)) + '/' + rails_dir

