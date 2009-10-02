# $Id$

LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/integration_spec_helper'
require File.dirname(__FILE__) + '/../../lib/workers/rss_worker'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/rssd_test.log')

describe BackupWorker::RSSStandalone do
  include IntegrationSpecHelper
  
  def verify_content_created
    @bs.feed.should be_a Feed
    #@bs.feed.etag.should_not be_nil
    @bs.feed.last_modified.should_not == ''
    @bs.feed.entries.should have_at_least(1).things
  end
  
  before(:each) do
    # Rails env already loaded
    BackupWorker::RSSStandalone.any_instance.stubs(:load_rails_environment)
  end

  #it "should not raise exception on invalid feed urls" do
  #  setup_db BackupSite::Blog, nil, nil, :rss_url => 'http://feeds.feedburner.com/foofoo'
  #  @bw = BackupWorker::RSSStandalone.new('test')
  #  @bw.expects(:save_success_data).never
  #  @bw.run(publish_workitem)
  #end

  describe "initial run" do
    before(:each) do
      setup_db BackupSite::Blog, nil, nil, :rss_url => 'http://simian187.vox.com'
    end
    
    it "should not raise exception if feed url is invalid" do  
      FeedUrl.any_instance.stubs(:rss_url).returns('http://foofoo')
      bw = BackupWorker::RSSStandalone.new('test')
      bw.run(publish_workitem)
      BackupSourceJob.last.error_messages.should == nil
    end
    
    describe "with feed requiring authentication" do
      it "should fail with invalid user/pass" do
        FeedUrl.any_instance.stubs(:auth_required?).returns(true)
        FeedUrl.any_instance.expects(:valid_parse_result).never
        bw = BackupWorker::RSSStandalone.new('test')
        bw.run(publish_workitem)
        (j = BackupSourceJob.last).status.should_not == BackupStatus::Success
        j.error_messages.to_s.should =~ /login/i
      end
      
      # Need to test auth with a real feed
      it "should succeed with valid user/pass"
    end
  
    # This test must run last in the block!
    it "should save job run info to backup source job record" do
      bw = BackupWorker::RSSStandalone.new('test')
      bw.run(publish_workitem)
      verify_successful_backup(BackupSourceJob.last)
      verify_content_created
    end
  end
  
  describe "subsequent runs" do
    before(:each) do
      load_db BackupSite::Blog
      @bw = BackupWorker::RSSStandalone.new('test')
    end
    
    it "should not re-save feed entries" do
      lambda {
        @bw.run(publish_workitem)
        verify_successful_backup(BackupSourceJob.last)
      }.should_not change(@bs.feed.entries, :size)
    end
  end
end