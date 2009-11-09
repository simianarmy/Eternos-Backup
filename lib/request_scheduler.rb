# $Id$

# RequestScheduler
#
# Implements rate-limiting on a per-app request level in order to avoid api errors such 
# as Facebook's  "Application request limit reached" and Twitter
# Thread-safe

# Usage:

# scheduler = RequestScheduler.new('facebook_backup', :delay => 1000, :max_per_minute => 10)
# Options:
# => delay: microseconds
# => max_per_minute: Max # requests / minute

# scheduler.execute do
#   your app request code
# end

# The class will delay execution your app request code if necessary, so make sure that any 
# timeout timers can handle possibly long delays.

require 'thread' # for Mutex

class RequestScheduler
  cattr_reader :lock
  @@lock = Mutex.new
  
  def initialize(app_name, options={})
    @app = app_name
    
    @delay = options[:delay] ? (options[:delay]/1000.to_f) : 0
    @max_per_minute = options[:max_per_minute] || 0
    set_last_request_time(nil)
  end
  
  def execute
    lock.synchronize do
      lr = last_request
      if lr && ((Time.now - lr) < @delay)
        sleep(@delay)
      end
      # Set the last request time to the time just before the request
      set_last_request_time(Time.now)
    end
    yield
  end
  
  def last_request
    Thread.main[@app]
  end
  
  def set_last_request_time(time)
    Thread.main[@app] = time
  end
end
