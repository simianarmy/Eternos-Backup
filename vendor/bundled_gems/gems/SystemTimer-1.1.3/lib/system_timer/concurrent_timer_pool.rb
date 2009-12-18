# Copyright 2008 David Vollbracht & Philippe Hanrigou

module SystemTimer
  
  class ConcurrentTimerPool
    
    def registered_timers
      @timers ||= []
    end
        
    def register_timer(trigger_time, thread)
      new_timer = ThreadTimer.new(trigger_time, thread)
      registered_timers << new_timer
      new_timer
    end

    def add_timer(interval_in_seconds)
      new_timer = register_timer(Time.now.to_i + interval_in_seconds, Thread.current)
      log_registered_timers if SystemTimer.debug_enabled?
      new_timer
    end
    
    def cancel(registered_timer)
      registered_timers.delete registered_timer
    end
    
    def first_timer?
      registered_timers.size == 1
    end
    
    def next_timer
      registered_timers.sort {|x,y| x.trigger_time <=> y.trigger_time}.first
    end

    def next_trigger_time
      timer = next_timer
      timer.trigger_time unless timer.nil?
    end

    def next_trigger_interval_in_seconds
      timer = next_timer
      [0, (timer.trigger_time - Time.now.to_i)].max unless timer.nil?
    end
    
    def next_expired_timer(now_in_seconds_since_epoch)
      candidate_timer = next_timer
      return nil if candidate_timer.nil? || 
                    candidate_timer.trigger_time > now_in_seconds_since_epoch
      candidate_timer
    end

    def trigger_next_expired_timer_at(now_in_seconds_since_epoch)
      timer = next_expired_timer(now_in_seconds_since_epoch)
      return if timer.nil?

      cancel timer
      log_timeout_received(timer) if SystemTimer.debug_enabled?
      timer.thread.raise Timeout::Error.new("time's up!")
    end

    def trigger_next_expired_timer
      trigger_next_expired_timer_at Time.now.to_i
    end
    
    def log_timeout_received(thread_timer)          #:nodoc:
      puts <<-EOS
        ==== Triger Timer ==== #{thread_timer}
            Main thread  : #{Thread.main}
            Timed_thread : #{thread_timer.thread}
            All Threads  : #{Thread.list.inspect}
      EOS
      log_registered_timers
    end

    def log_registered_timers          #:nodoc:
      puts <<-EOS
            Registered Timers: #{registered_timers.collect do |t| t.to_s end} 
      EOS
    end
    
  end
  
end