# $Id$

LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/../mq_spec_helper.rb'

require File.dirname(__FILE__) + '/../../lib/workers/twitter_worker'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/twitter_test.log')

describe BackupWorker::TwitterStandalone do
  include MQSpecHelper
  include WorkItemSpecHelper
  
  def load_db
    @member = Member.by_name('TEST TWITTER').first
    @bs = @member.backup_sources.by_site(BackupSite::Twitter).first
    @site = @bs.backup_site
  end
  
  def setup_db
    @member = create_member
    @member.update_attributes(:first_name => 'TEST', :last_name => 'TWITTER')
    @site = create_backup_site(:name => BackupSite::Twitter)
    @bs = BackupSource.create(:backup_site => @site, :member => @member, 
      :auth_login => 'eternostest', :auth_password => 'w7TpXpO8qAYAUW'
      )
  end
  
  def publish_workitem
    ruote_backup_workitem(@member, @bs)
  end
  
  def verify_successful_backup(bj)
    bj.created_at.should <= bj.finished_at
    bj.finished_at.should_not be_nil
    bj.status.should == BackupStatus::Success
    bj.percent_complete.should == 100
    bj.error_messages.should be_nil
  end
  
  def verify_content_created
    @member.activity_stream.items.should_not be_empty
    @member.activity_stream.items.first.should be_a TwitterActivityStreamItem
  end
  
  before(:each) do
    # Rails env already loaded
    BackupWorker::TwitterStandalone.any_instance.stubs(:load_rails_environment)
  end
  
  describe "initial run" do
    it "should save job run info to backup source job record" do
      setup_db 
      @bw = BackupWorker::TwitterStandalone.new('test')
      @bw.expects(:save_success_data)
      @bw.run(publish_workitem)
      @bs.reload.needs_initial_scan.should be_false
      verify_successful_backup(BackupSourceJob.last)
      verify_content_created
    end
  end
  
  describe "subsequent runs" do
    before(:each) do
      load_db
      @bw = BackupWorker::TwitterStandalone.new('test')
      @bw.expects(:save_success_data)
    end
    
    it "should not re-save feed entries" do
      lambda {
        @bw.run(publish_workitem)
        verify_successful_backup(BackupSourceJob.last)
      }.should_not change(@member.activity_stream.items, :count)
    end
  end
end