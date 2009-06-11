# $Id$

require 'benchmark'

module BackupDaemonHelper
  def load_rails_environment(env)
    ENV['RAILS_ENV'] = env
    mark = Benchmark.realtime do
      rails_dir = DaemonKit.arguments.options[:railsdir] rescue DEFAULT_RAILS_PATH
      require File.join(rails_dir, 'config', 'environment')
    end
    log_info "loaded rails environment... #{mark} seconds"
  end
  
  def log_info(*args)
    DaemonKit.logger.info *args
  end
  
  def log_debug(*args)
    DaemonKit.logger.debug *args
  end
end