# $Id$

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/../mq_spec_helper.rb'

require File.dirname(__FILE__) + '/../../lib/workers/backupd_worker'
require 'active_record/base'

module WorkItemSpecHelper
  def create_workitem
    json = <<-JSON
          {"last_modified": "2009/04/23 12:49:07 +0200",
           "type": "OpenWFE::InFlowWorkItem",
           "participant_name": "toto",
           "attributes": {"shallow": "true", "nes": {"ted": "yes" } },
           "links": [{"href": "http://localhost:4567/workitems", "rel": "via"},
             {"href": "http://localhost:4567/workitems/20090413-juduhojewo/0_0_0_0_1", "rel": "self"}],
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

    RuoteExternalWorkitem.parse( json )
  end
end

describe BackupWorker do
  include MQSpecHelper
  include WorkItemSpecHelper
  
  describe BackupWorker::Base do
    before(:each) do
      BackupWorker::Base.any_instance.expects(:load_rails_environment)
    end
    
    describe "on new" do  
      it "should create object" do
        @bw = BackupWorker::Base.new(ENV['DAEMON_ENV'])
        @bw.should be_an_instance_of BackupWorker::Base
      end
    end
    
    describe "on run" do
      before(:each) do
        @bw = BackupWorker::Base.new(ENV['DAEMON_ENV'])
      end
      
      it "should start workitem listen loop" do
        MessageQueue.expects(:start).yields
        MessageQueue.expects(:backup_worker_subscriber_queue).with('base').returns(@q = mock)
        @q.expects(:subscribe).yields(@msg = 'FOO')
        RuoteExternalWorkitem.expects(:parse).with(@msg)
        @bw.expects(:process_message)
        @bw.expects(:send_results)
        @bw.run
      end
    end
    
    describe "on process message" do
      class BackupSource; end
      
      before(:each) do
        @wi = create_workitem
        @wi['target'] = {'id' => 1000}
        @bw = BackupWorker::Base.new(ENV['DAEMON_ENV'])
      end
      
      describe "on backup source record lookup error" do
        before(:each) do
          BackupSource.expects(:find).with(@wi['target']['id']).raises(ActiveRecord::RecordNotFound)
        end
        
        it "should handle exception and save error" do
          class BackupSource; end
          lambda {
            @bw.expects(:save_error)
            @bw.process_message(@wi)
          }.should_not raise_error
        end
      
        it "should save error in workitem attributes" do
          @bw.process_message(@wi)
          @wi['worker']['status'].should == 500
          @wi['worker']['error'].should match(/Invalid BackupSource ID/)
        end
      end
      
      describe "on backup source record found" do
        before(:each) do
          BackupSource.expects(:find).with(@wi['target']['id']).returns(@bs = mock)
        end
        
        it "should start backup with backup source passed as arg" do
          @bw.expects(:backup).with(@bs)
          @bw.process_message(@wi)
        end
      end
    end
  end
end
