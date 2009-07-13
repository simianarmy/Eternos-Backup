# $Id$

LOAD_RAILS = true
require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/../mq_spec_helper.rb'

require File.dirname(__FILE__) + '/../../lib/workers/backupd_worker'
require 'ruote_external_workitem'

describe BackupWorker do
  include MQSpecHelper
  include WorkItemSpecHelper
  
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
  end
  
  describe BackupWorker::Base, "as QueueRunner" do
    before(:each) do
      BackupWorker::Base.any_instance.expects(:load_rails_environment)
      @bw = BackupWorker::Base.new(ENV['DAEMON_ENV'])
      @bw.class_eval do
        include BackupWorker::QueueRunner
      end
      @bw.stubs(:verify_database_connection!)
    end
    
    describe "on new" do  
      it "should create object" do
        @bw.should be_an_instance_of BackupWorker::Base
      end
    end
    
    describe "on run" do
      before(:each) do
        @rw = create_backup_workitem
      end
      
      it "should parse incoming workitems and send to backup method" do
        MessageQueue.expects(:start).yields
        MessageQueue.expects(:backup_worker_subscriber_queue).returns(@q = mock('MessageQueue'))
        @q.expects(:subscribe).yields(stub('mq_header', :ack => true), @rw)
        BackupWorker::WorkItem.expects(:new).with(@rw).returns(@wi=mock('WorkItem'))
        @bw.expects(:run_backup_job).with(@wi).yields(@job=mock('BackupJob'))
        #@bw.expects(:backup).with(@job)
        @bw.expects(:send_results)
        @bw.run
      end
    
      describe "on processing workitem" do
        before(:each) do
          @workitem = BackupWorker::WorkItem.new(@rw)
          BackupWorker::WorkItem.expects(:new).with(@rw).returns(@workitem)
        end
      
        describe "on backup source record create error" do
          before(:each) do
            BackupSourceJob.stubs(:create!).raises('error')
          end
        
          it "should not run backup if workitem backup source not found in database" do
            @bw.expects(:save_error)
            lambda {
              @bw.process_message(@rw)
            }.should_not raise_error
          end
      
          it "should save error in workitem attributes" do
            @bw.process_message(@rw)
            @workitem.wi['worker']['status'].should == 500
            @workitem.wi['worker']['error'].should match(/Error creating BackupSourceJob/)
          end
        end
      
        describe "on backup source record found" do
          before(:each) do
            BackupSourceJob.stubs(:create!).returns(@bj = mock_model(BackupSourceJob))
            @bj.expects(:finished_at=)
            @bj.expects(:save)
          end
        
          it "should yield new backup source job object" do
            @bw.expects(:backup).with(@bj)
            @bw.process_message(@rw)
          end
        end
        
        describe "on backup" do
          before(:each) do
            BackupSourceJob.stubs(:create!).returns(@bj = mock_model(BackupSourceJob))
            @bj.stubs(:backup_source).returns(@bs = mock_model(BackupSource))
            @bj.expects(:finished_at=)
            @bj.expects(:save)
          end
          
          it "should update backup source object & job object on auth failure" do
            @bw.stubs(:authenticate).returns(false)
            @bs.expects(:login_failed!)
            @bw.expects(:save_error)
            @bw.process_message(@rw)
          end
        end
      end
    end
  end
end
