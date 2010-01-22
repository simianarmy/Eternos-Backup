# $Id$

LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/integration_spec_helper'
require File.dirname(__FILE__) + '/../../lib/workerd'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/rssd_test.log')

describe BackupWorker::RSS do
  include IntegrationSpecHelper
  
  def verify_content_created
    @bs.feed.should be_a Feed
    #@bs.feed.etag.should_not be_nil
    @bs.feed.last_modified.should_not == ''
    @bs.feed.entries.should have_at_least(1).things
  end
  
  before(:all) do
    overload_amqp
    setup_db BackupSite::Blog, nil, nil, :rss_url => 'http://simian187.vox.com'
    test_json_conflict
    @source = BackupSite::Blog
    @worker = create_worker_queue
    @worker.run
  end

  with_transactional_fixtures(:off) do
  describe "initial run" do
    before(:each) do
      mock_queues
    end
    
    it "should not raise exception if feed url is invalid" do  
      FeedUrl.any_instance.stubs(:rss_url).returns('http://foofoo')
      publish_job(@source)
      BackupSourceJob.last.error_messages.should == nil
    end
    
    describe "with feed requiring authentication" do
      before(:each) do
        FeedUrl.any_instance.stubs(:rss_url).returns('http://AUTHREQUIRED_SHOULDFAIL_URL')
        FeedUrl.any_instance.stubs(:auth_required?).returns(true)
      end
      
      it "should save login failed in job record error messages" do
        publish_job(@source) 
        j = BackupSourceJob.last
        j.error_messages.to_s.should match(/login/i)
      end
      # Need to test auth with a real feed
    end
  
    # This test must run last in the block!
    it "should save job run info to backup source job record" do
      publish_job(@source)
      verify_successful_backup(BackupSourceJob.last)
      verify_content_created
    end
  end
  
  describe "subsequent runs" do
    before(:each) do
      mock_queues
      publish_job(@source)
    end
    
    it "should not re-save feed entries" do
      lambda {
        publish_job(@source)
      }.should_not change(@bs.feed.entries, :size)
    end
  end
  end
end