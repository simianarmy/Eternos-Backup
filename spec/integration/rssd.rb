# $Id$

LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/../mq_spec_helper.rb'

require File.dirname(__FILE__) + '/../../lib/workers/rss_worker'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/rssd_test.log')

describe BackupWorker::RSSStandalone do
  include MQSpecHelper
  include WorkItemSpecHelper
  
  def load_db
    @member = Member.by_name('TEST RSS').first
    @bs = @member.backup_sources.by_site(BackupSite::Blog).first
    @site = @bs.backup_site
  end
  
  def setup_db
    @member = create_member
    @member.update_attributes(:first_name => 'TEST', :last_name => 'RSS')
    @site = create_backup_site(:name => BackupSite::Blog)
    @bs = FeedUrl.create(:backup_site => @site, :member => @member, 
      :rss_url => 'http://simian187.vox.com/library/posts/atom.xml')
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
    @bs.feed.should_not be_nil
    #@bs.feed.etag.should_not be_nil
    @bs.feed.last_modified.should_not be_nil
    @bs.feed.entries.should_not be_empty
  end
  
  before(:each) do
    # Rails env already loaded
    BackupWorker::RSSStandalone.any_instance.stubs(:load_rails_environment)
    @source = BackupSite::Blog
  end
  
  describe "initial run" do
    it "should save job run info to backup source job record" do
      setup_db 
      @bw = BackupWorker::RSSStandalone.new('test')
      @bw.expects(:save_success_data)
      @bw.run(publish_workitem)
      verify_successful_backup(BackupSourceJob.last)
      verify_content_created
    end
  end
  
  describe "subsequent runs" do
    before(:each) do
      load_db
      @bw = BackupWorker::RSSStandalone.new('test')
      @bw.expects(:save_success_data)
    end
    
    it "should not re-save feed entries" do
      lambda {
        @bw.run(publish_workitem)
        verify_successful_backup(BackupSourceJob.last)
      }.should_not change(@bs.feed.entries, :count)
    end
  end
end