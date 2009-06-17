# $Id$

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/../mq_spec_helper.rb'

require File.dirname(__FILE__) + '/../../lib/workers/backupd_worker'
require 'active_record/base'

module WorkItemSpecHelper
  def ruote_workitem
    json = <<-JSON
          {"last_modified": "2009/04/23 12:49:07 +0200",
           "type": "OpenWFE::InFlowWorkItem",
           "participant_name": "toto",
           "attributes": {"target": {"id": "100"}, "job_id": "1"},
           "dispatch_time": "2009/04/23 12:49:07 +0200",
           "flow_expression_id": {"workflow_definition_url": "field:__definition",
           "expression_name": "toto",
           "workflow_definition_name": "TestExternal",
           "owfe_version": "0.9.21",
           "workflow_definition_revision": "0",
           "workflow_instance_id": "20090413-juduhojewo",
           "engine_id": "ruote_rest",
           "expression_id": "0.0.0.0.1"}}
    JSON
  end
end

describe BackupWorker do
  include MQSpecHelper
  include WorkItemSpecHelper
  
  describe BackupWorker::WorkItem do
    before(:each) do
       @rw = ruote_workitem
       @wi = RuoteExternalWorkitem.parse(@rw)
    end
    
    it "should parse external ruote workitem on initialize" do
      BackupWorker::WorkItem.new(@rw).should be_an_instance_of BackupWorker::WorkItem
    end
    
    it "should return source id attribute from workitem" do
      BackupWorker::WorkItem.new(@rw).source_id.should == @wi['target']['id']
    end
    
    it "should return job id attribute from workitem" do
      BackupWorker::WorkItem.new(@rw).job_id.should == @wi['job_id']
    end
  end
  
  describe BackupWorker::Base do
    before(:each) do
      BackupWorker::Base.any_instance.expects(:load_rails_environment)
      @bw = BackupWorker::Base.new(ENV['DAEMON_ENV'])
    end
    
    describe "on new" do  
      it "should create object" do
        @bw.should be_an_instance_of BackupWorker::Base
      end
      
      it "should update backup source object on authentication failure" do
        @source = mock('BackupSource')
        
        @bw.auth_failed
      end
    end
    
    describe "on run" do
      before(:each) do
        @rw = ruote_workitem
      end
      
      it "should start workitem listen loop" do
        MessageQueue.expects(:start).yields
        MessageQueue.expects(:backup_worker_subscriber_queue).with('base').returns(@q = mock)
        @q.expects(:subscribe).yields(@rw)
        BackupWorker::WorkItem.expects(:new).with(@rw).returns(@wi=mock)
        @bw.expects(:create_job).with(@wi).yields(@job=mock)
        @bw.expects(:backup).with(@job)
        @job.expects(:save)
        @bw.expects(:send_results)
        @bw.run
      end
    
      describe "on workitem received" do
        # mock activerecord classes
        class BackupSource; end
        class BackupSourceJob; end
        
        before(:each) do
          @workitem = BackupWorker::WorkItem.new(@rw)
        end
      
        describe "on backup source record lookup error" do
          before(:each) do
            BackupSource.expects(:find).with(@workitem.source_id).raises(ActiveRecord::RecordNotFound)
          end
        
          it "should handle exception and save error" do
            lambda {
              @bw.expects(:save_error)
              @bw.create_job(@workitem)
            }.should_not raise_error
          end
      
          it "should save error in workitem attributes" do
            @bw.create_job(@workitem)
            @workitem['worker']['status'].should == 500
            @workitem['worker']['error'].should match(/create_job exception/)
          end
        end
      
        describe "on backup source record found" do
          before(:each) do
            BackupSource.expects(:find).with(@workitem.source_id).returns(@bs = mock)
          end
        
          it "should yield backup source job object" do
            BackupSourceJob.expects(:create).with(:backup_source => @bs, :backup_job_id => @workitem.job_id)
            @bw.create_job(@workitem)
          end
        end
      end
    end
  end
end
