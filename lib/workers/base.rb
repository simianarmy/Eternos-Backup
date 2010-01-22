# $Id$


module BackupWorker    
  # Base class for all site-specific worker classes
  class Base
    include BackupDaemonHelper # For logger

    class_inheritable_accessor :site, :actions, :increment_step
    attr_reader :backup_job, :backup_source, :errors
    
    self.site    = 'base'
    self.actions = []
    
    def initialize(backup_job)
      @backup_job     = backup_job
      @backup_source  = backup_job.backup_source
      @errors         = []
      self.increment_step = 100 / [self.actions.size, 1].max
    end
    
    # Implement in child classes
    def authenticate
      false
    end
    
    # Runs child class actions 
    def run
      actions.each {|action| send("save_#{action}")}
    end
    
    def update_completion_counter(step=increment_step)
      backup_job.increment!(:percent_complete, step) unless backup_job.percent_complete >= 100
    end

    def set_completion_counter(val=100)
      backup_job.update_attribute(:percent_complete, val)
    end

    protected

    def member
      backup_source.member
    end
    
    def save_error(err)
      log :error, err
      @errors << err
    end
    
    def save_exception(msg, e)
      save_error "#{msg}: #{e.to_s} #{e.backtrace}"
      log :error, e.backtrace
    end
  end
end

