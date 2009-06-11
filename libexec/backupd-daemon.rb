# Change this file to be a wrapper around your daemon code.

# Do your post daemonization configuration here
# At minimum you need just the first line (without the block), or a lot
# of strange things might start happening...
DaemonKit::Application.running! do |config|
  # Trap signals with blocks or procs
  config.trap( 'INT' ) do
    DaemonKit.logger.info 'Caught INT'
    AMQP.stop { EM.stop }
  end
  config.trap( 'TERM' ) do
    DaemonKit.logger.info 'Caught TERM'
    AMQP.stop { EM.stop }
  end
end

MQ.error("MQ error handler") do 
  DaemonKit.logger.error "MQ error handler invoked"
  AMQP.stop { EM.stop }
end

# Fire up custom daemon class instance
require File.join(DAEMON_ROOT, 'config', 'arguments')

BackupDaemon.new(ENV['DAEMON_ENV']).run