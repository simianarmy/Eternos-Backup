# $Id$

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
    ActiveRecord::Base.logger = DaemonKit.logger
    
    require 'ar_thread_patches'
  end
  
  # We shouldn't need this anymore know that we monkey-patched execute in ar_thread_patches
  # keep it around just in case...
  def verify_database_connection!
    # Make sure this is on since we're threading
    tries = 0
    begin
      tries += 1
      ActiveRecord::Base.verify_active_connections!
    rescue 
      unless tries > 3
        ActiveRecord::Base.connection.reconnect! 
        retry
      end
      log_error "Could not verify db connection!"
      raise
    end
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
      DaemonKit.logger.debug args.join("\n")
    when :info
      DaemonKit.logger.info args.join("\n")
    when :warn
      DaemonKit.logger.warn args.join("\n")
    when :error
      DaemonKit.logger.error args.join("\n")
    end
  end
end