# $Id$

require 'rubygems'
require 'benchmark'

module BackupDaemonHelper
  def load_rails_environment(env)
    ENV['RAILS_ENV'] = env
    log_info "Loading rails from #{RAILS_ROOT}"
    log_info "Loading rails env in #{env} mode..."
    mark = Benchmark.realtime do
      rails_dir = DaemonKit.arguments.options[:railsdir] || RAILS_ROOT
      require File.join(rails_dir, 'config', 'environment')
    end
    log_info "loaded rails environment... #{mark} seconds"
  end
  
  def log_info(*args)
    log :info, *args
  end
  
  def log_debug(*args)
    log :debug, *args
  end
  
  def log(level, *args)
    case level
    when :debug
      DaemonKit.logger.debug *args
    when :info
      DaemonKit.logger.info *args
    when :warn
      DaemonKit.logger.warn *args
    when :error
      DaemonKit.logger.error *args
    end
  end
end