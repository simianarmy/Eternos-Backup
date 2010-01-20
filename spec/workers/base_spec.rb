# $Id$

require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/../mq_spec_helper'
require File.dirname(__FILE__) + '/../../lib/workers/base'

describe BackupWorker::Base do
  def create_backup_job
    stub('backup_job', :backup_source => stub('backup_source'))
  end
  
  before(:each) do 
    @worker = BackupWorker::Base.new(@job = create_backup_job)
  end
  
  describe "on create" do
    it "should use a default increment step of 100 when no actions defined" do
      @worker.actions.should be_empty
      @worker.increment_step.should == 100
    end
    
    it "should enable log method" do
      @worker.should respond_to :log
    end
    
    it "should return job's backup source" do
      @worker.backup_source.should == @job.backup_source
    end
  end
  
  describe "on run" do
    it "should call each method in actions array using save_ prefix" do
      @worker.actions = [:foome, :fooyou]
      @worker.expects(:save_foome)
      @worker.expects(:save_fooyou)
      @worker.run
    end
  end
end
