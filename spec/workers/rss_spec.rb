# $Id$

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/../mq_spec_helper.rb'
require RAILS_ROOT + '/app/models/backup_status'
require File.dirname(__FILE__) + '/../../lib/workers/rss_worker'

describe BackupWorker::RSS do
  include MQSpecHelper

  def setup_backup_worker
    @bw = BackupWorker::RSSQueueRunner.new(ENV['DAEMON_ENV'])
    @job = mock('BackupSourceJob')
    @job.stubs(:backup_source).returns(@source = mock('BackupSource'))
    @job.stubs(:status)
    @source.stubs(:member).returns(@member = mock('Member'))
    @member.stubs(:id).returns(1)  
  end
  
  it "should return backup actions" do
    BackupWorker::RSS.actions.should_not be_empty
  end
  
  describe "without rails" do
    describe "on backup" do
      before(:each) do
        BackupWorker::RSSQueueRunner.any_instance.expects(:load_rails_environment)
        setup_backup_worker
      end
    
      def stub_jobs(*exceptions)
        ([:save_items] - exceptions).each do |meth|
          @bw.stubs(meth)
        end
      end
      
      describe "logging in" do
        before(:each) do
          @bw.stubs(:actions).returns([])
          @bw.stubs(:save_error)
        end
        
        describe "on auth required" do
          before(:each) do
            @source.stubs(:auth_required?).returns(true)
          end
          
          describe "on failure" do
            it "should save auth error values and stop" do
              @bw.stubs(:authenticate).returns(false)
              @bw.expects(:auth_failed)
              @bw.backup(@job)
            end
          end
        end
        
        describe "on auth not required" do
          it "should always succeed" do
            @source.stubs(:auth_required?).returns(false)
            @bw.expects(:auth_failed).never
            @job.expects(:status=).with(BackupStatus::Success)
            @bw.backup(@job)
          end
        end
      end
    
      describe "logged in" do
        before(:each) do
          @job.stubs(:status=)
          @job.stubs(:increment!)
        end
      
        describe "saving new feed entries" do
          before(:each) do
            @source.stubs(:feed).returns(@feed = mock('RSSFeed'))
          end
        
          describe "on success" do
            before(:each) do
              @feed.expects(:update_from_feed).with(nil)
            end
          end
        end
      end
    end
  end
end
  