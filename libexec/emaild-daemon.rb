# $Id$

require File.join(DAEMON_ROOT, 'lib', 'workers', 'email_worker')

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
#ENV['DAEMON_ENV'] = 'test'

BackupWorker::EmailQueueRunner.new(ENV['DAEMON_ENV']).run
