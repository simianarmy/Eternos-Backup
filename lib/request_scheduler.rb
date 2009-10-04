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

class RequestScheduler
  def initialize(app_name, options={})
    @app = app_name
    
    @delay = options[:delay] ? (options[:delay]/1000.to_f) : 0
    @max_per_minute = options[:max_per_minute] || 0
    set_last_request_time(nil)
  end
  
  def execute
    if last_request && ((Time.now - last_request) < @delay)
      puts "Scheduler sleeping for #{@delay} seconds"
      sleep(@delay)
    end
    ret = yield
    # Set the last request time to the time *after* completion of the request
    set_last_request_time(Time.now)
    ret
  end
  
  def last_request
    Thread.current[@app]
  end
  
  def set_last_request_time(time)
    Thread.current[@app] = time
  end
end
