# $Id$

LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/../mq_spec_helper.rb'

require File.dirname(__FILE__) + '/../../lib/workers/facebook_worker'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/facebookd_test.log')

describe BackupWorker::FacebookStandalone do
  include MQSpecHelper
  include WorkItemSpecHelper
  
  def create_facebook_member
    member = create_member
    member.update_attribute(:facebook_id, 1005737378)
    member.set_facebook_session_keys(
      'c4c3485e22162aeb0be835bb-1005737378', 
      '6ef09f021c983dbd7d04a92f3689a9a5')
    member
  end
  
  def setup_db
    @member = create_facebook_member
    @site = create_backup_site(:name => 'facebook')
    @bs = create_backup_source(:backup_site => @site, :member => @member)
  end
  
  def mock_facebook_user
    @fb_user = FacebookBackup::User.stubs(:new).returns(mock('FacebookBackup::User'))
  end
  
  def mock_mq
    # Stub MQ methods - not using EventMachine in specs
    MQ.stubs(:error)
    MessageQueue.stubs(:start)
    MessageQueue.expects(:backup_worker_subscriber_queue).with('facebook').returns(@q = mock)
    @q.expects(:subscribe).yields(publish_workitem)
  end
  
  def publish_workitem
    ruote_backup_workitem(@member, @bs)
  end
  
  def verify_successful_backup
    bj = BackupSourceJob.last
    bj.created_at.should <= bj.finished_at
    bj.finished_at.should be_close(Time.now, 5)
    bj.status.should == BackupStatus::Success
    bj.percent_complete.should == 100
    bj.error_messages.should be_nil
  end
  
  def verify_backup_content_created
    @member.profile.should_not be_nil
    @member.profile.facebook_data.should have_key(:birthday)
    fb_content = @member.profile.facebook_content
    fb_content.should_not be_nil
    fb_content.friends.should be_a Array
    fb_content.friends.should_not be_empty
    fb_content.groups.should be_a Array # Can be empty, just not nil
    @bs.backup_photo_albums.should_not be_empty
    @bs.backup_photo_albums.first.backup_photos.should_not be_empty
    @member.activity_streams.should_not be_empty
    @member.activity_streams.first.backup_site.should == @site
    @member.activity_streams.first.activity_stream_items.should_not be_empty
  end
  
  before(:each) do
    # Rails env already loaded
    BackupWorker::FacebookStandalone.any_instance.stubs(:load_rails_environment)
    @source = 'facebook'
    setup_db
  end
  
  # It raises stack level too deep error in run spec
  it "should be able to create backup job object" do
    lambda {
      BackupSourceJob.create(:backup_source_id => @bs.id, :backup_job_id => 100)
    }.should_not raise_error
  end
  
  it "should process backup job" do
    @bw = BackupWorker::FacebookStandalone.new('test')
    @bw.expects(:backup)
    @bw.run(publish_workitem)
  end
  
  it "should create backup source job record" do
    lambda {
      @bw = BackupWorker::FacebookStandalone.new('test')
      @bw.run(publish_workitem)
    }.should change(BackupSourceJob, :count).by(1)
  end
  
  it "should save job run info to backup source job record" do
    @bw = BackupWorker::FacebookStandalone.new('test')
    @bw.expects(:save_success_data)
    @bw.run(publish_workitem)
    
    verify_successful_backup 
    verify_backup_content_created
  end
end