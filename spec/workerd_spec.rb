# $Id$

LOAD_RAILS = true
require File.dirname(__FILE__) + '/spec_helper.rb'
require File.dirname(__FILE__) + '/mq_spec_helper.rb'
require File.dirname(__FILE__) + '/../lib/workerd'
require 'ruote_external_workitem'
require 'moqueue'

describe BackupWorker do
  include MQSpecHelper
  include WorkItemSpecHelper
  include BackupHelperSpecHelper
  
  def create_backup_workitem
    @member = mock('Member', :id => 1)
    @backup_source = mock('BackupSource', :backup_site => mock('BackupSite', :name => 'test'))
    ruote_backup_workitem(@member, @backup_source)
  end
  
  describe BackupWorker::WorkItem do
    before(:each) do
      @rw = create_backup_workitem
      @wi = RuoteExternalWorkitem.parse(@rw)
      @item = BackupWorker::WorkItem.new(@rw)
    end
    
    it "should parse external ruote workitem on initialize" do
      @item.should be_an_instance_of BackupWorker::WorkItem
    end
    
    it "should return source id attribute from workitem" do
      @item.source_id.should == @wi['target']['id']
    end
    
    it "should return job id attribute from workitem" do
      @item.job_id.should == @wi['job_id']
    end
  
    it "should be able to convert workitem back to json format" do
      lambda {
        @item.to_json
      }.should_not raise_error
    end
    
    describe "on save_error" do
      it "should set status and error message" do
        @item.save_error('foo')
        @item.wi['worker']['error'].should == ['foo']
        @item.wi['worker']['status'].should == 500
      end
    end
  end
  
  describe BackupWorker::WorkerFactory do
    before(:each) do
      @bj = stub('backup_job', :backup_source => stub('backup_source'))
    end
    
    it "should return a worker object instance" do
      @target = BackupWorker::Facebook.site
      obj = BackupWorker::WorkerFactory.create_worker(@target, @bj)
      obj.should be_a BackupWorker::Facebook
    end
  end
      
  describe BackupWorker::Queue do
    before(:each) do
      stub_logger
      BackupWorker::Queue.any_instance.expects(:load_rails_environment)
      @bw = BackupWorker::Queue.new('test')
    end
    
    describe "on new" do  
      it "should create object" do
        @bw.should be_an_instance_of BackupWorker::Queue
      end
    end
    
    describe "on run" do
      before(:all) do
        overload_amqp
      end
      
      before(:each) do
        @rw = create_backup_workitem
        reset_broker
        MessageQueue.stubs(:start).yields
        MessageQueue.stubs(:backup_worker_subscriber_queue).returns(@q = MQ.new.queue('backup_worker_queue'))
        @q.publish(@rw)
        #MessageQueue.stubs(:backup_worker_subscriber_queue).with('*').returns(@q = stub('MessageQueue', :name => 'foo'))
        #@q.stubs(:subscribe).yields(@mq_header = stub('mq_header'), @rw)
      end
      
      it "should parse incoming workitems and send to backup method" do
        BackupWorker::WorkItem.expects(:new).with(@rw).returns(@wi=mock('WorkItem'))
        @bw.expects(:run_backup_job).with(@wi).yields(@job=mock('BackupJob'))
        @bw.expects(:backup).with(@job)
        @bw.expects(:send_results)
        @bw.run
      end
    
      describe "on processing workitem" do 
        before(:each) do
          @workitem = BackupWorker::WorkItem.new(@rw)
          @response_q = MQ.new.queue('ruote_backup_feedback')
          BackupSourceJob.stubs(:cleanup_connection).yields
          @bj = BackupSourceJob.new
        end
      
        describe "on backup source job record create error" do
          before(:each) do
            BackupSourceJob.stubs(:find_or_create_by_backup_source_id_and_backup_job_id).raises(BackupWorker::Queue::BackupSourceNotFoundException)
          end
        
          it "should not run backup" do
            @bw.expects(:backup).never
            @bw.run
          end
      
          it "should include error in response message" do
            @bw.expects(:save_error)
            @bw.run
          end
        end
      
        describe "on backup source record found" do
          before(:each) do
            BackupSourceJob.stubs(:find_or_create_by_backup_source_id_and_backup_job_id).returns(@bj)
            @bj.stubs(:backup_source).returns(mock_model(BackupSource))
          end
        
          it "should yield new backup source job object" do
            @bw.expects(:backup).with(@bj).returns(true)
            @bw.expects(:save_success_data)
            @bj.expects(:finished!)
            @bw.run
          end
        
          describe "on backup" do
            before(:each) do
              BackupWorker::WorkItem.any_instance.stubs(:source_name).returns('facebook')
              BackupWorker::Facebook.expects(:new).with(@bj).returns(@worker = stub('worker'))
            end

            it "should instantiate worker instance based on backup source" do
              @worker.expects(:authenticate).returns(true)
              @worker.expects(:run)
              @bw.run
            end
          end
        end
      end
    end
  end
end
