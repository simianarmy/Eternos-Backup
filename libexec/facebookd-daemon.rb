# $Id$

require File.join(DAEMON_ROOT, 'lib', 'workers', 'facebook_worker')

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

# Fire up custom daemon class instance
require File.join(DAEMON_ROOT, 'config', 'arguments')


BackupWorker::FacebookQueueRunner.new(DaemonKit.env).run
