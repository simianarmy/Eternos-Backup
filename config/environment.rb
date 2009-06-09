# Be sure to restart your daemon when you modify this file

# Uncomment below to force your daemon into production mode
#ENV['DAEMON_ENV'] ||= 'production'

# Boot up
require File.join(File.dirname(__FILE__), 'boot')

DaemonKit::Initializer.run do |config|

  # The name of the daemon as reported by process monitoring tools
  config.daemon_name = 'backupd'

  # Uncomment to allow multiple instances to run
  # config.mulitple = true

  # Force the daemon to be killed after X seconds from asking it to
  # config.force_kill_wait = 30

  # Configure the safety net (see DaemonKit::Safety)
  # This doesn't work yet...
  # config.safety_net.handler = :mail # (or :hoptoad )
  # config.safety_net.mail.recipients = ['marc@eternos.com']
end

DEFAULT_RAILS_PATH = File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'eternos.com')

# Load plugins
plugin_path = File.join(File.dirname(__FILE__), '..', 'vendor', 'plugins')
Dir.entries(plugin_path).each do |path|
  if File.directory?(File.join(plugin_path, path)) and (path !~ /^\./)
    require(File.join(plugin_path, path, 'init'))
  end
end

