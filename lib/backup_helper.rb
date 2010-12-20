# $Id$

require 'benchmark'

module BackupDaemonHelper
  def load_rails_environment(env)
    ENV['RAILS_ENV'] = env
    log_info "Loading rails from #{RAILS_ROOT}"
    log_info "Loading rails env in #{env} mode..."
    
    mark = Benchmark.realtime do
      rails_dir = (DaemonKit.arguments.options[:railsdir] rescue nil) || RAILS_ROOT
      require File.join(rails_dir, 'config', 'environment')
    end
    log_info "loaded rails environment... #{mark} seconds"
    log_info "Facebooker using curl? #{Facebooker.use_curl?}"
    log_info "Facebooker timeout => #{Facebooker.timeout}"
    # Do post-rails initializations
    Facebooker.logger = DaemonKit.logger
    ActiveRecord::Base.logger = DaemonKit.logger
    require File.join(DaemonKit.root, 'lib', 'ar_thread_patches')
    require File.join(DaemonKit.root, 'lib', 'facebooker_curl_patch')
    require File.join(DaemonKit.root, 'lib', 'facebook', 'backup_user')
    turn_off_thinking_sphinx
  end
  
  # Wraps activerecord query block in patched with_connection method
  # to ensure threaded connections are released to pool after every query
  def safe_query
    ActiveRecord::Base.connection_pool.with_connection { yield }
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
  
  # Disable damn ThinkingSphinx after_commit stupidity
  # If not, it will call 'populate' and attempts to search when 
  # a AR model that defines indexes is updated!
  def turn_off_thinking_sphinx
    ThinkingSphinx.define_indexes = false
    ThinkingSphinx.deltas_enabled = false
    ThinkingSphinx.updates_enabled = false
  end
end
