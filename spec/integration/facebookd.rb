# $Id$

LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/integration_spec_helper'

require File.dirname(__FILE__) + '/../../lib/workers/facebook_worker'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/facebookd_test.log')

describe BackupWorker::FacebookStandalone do
  include IntegrationSpecHelper
  @@member_id = 0
  
  def marc_fb_info
    {:id => 1005737378,
      :session =>  'c4c3485e22162aeb0be835bb-1005737378', 
      :secret => '6ef09f021c983dbd7d04a92f3689a9a5'}
  end
  
  def andy_fb_info
    {:id => 504883639,
      :session => '2.DPd4uDYC2w7fBrDtg3IRZA__.86400.1246140000-504883639',
      :secret => 'oMlcrlaGX_8C6b3_C9oXqw__'}
  end
  
  def create_facebook_member(fb_info)
    member = create_member
    member.update_attributes(:first_name => "facebook test - #{fb_info[:id]}", 
      :facebook_id => fb_info[:id])
    member.set_facebook_session_keys(fb_info[:session], fb_info[:secret])
    member
  end
  
  def setup_db(fb_info)
    @member = create_facebook_member fb_info
    @@member_id = @member.id
    @site = create_backup_site(:name => BackupSite::Facebook)
    setup_backup_source(BackupSite::Facebook)
  end
  
  def load_db(user_id=@@member_id)
    @member = Member.find(user_id)
    @bs = @member.backup_sources.by_site(BackupSite::Facebook).first
    @site = @bs.backup_site
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
  
  def verify_backup_content_created
    @member.profile.should_not be_nil
    @member.profile.reload.facebook_data.should have_key(:birthday)
    fb_content = @member.profile.facebook_content
    fb_content.should_not be_nil
    fb_content.friends.should be_a Array
    fb_content.friends.should_not be_empty
    fb_content.groups.should be_a Array # Can be empty, just not nil
    @bs.backup_photo_albums.should_not be_empty
    @bs.backup_photo_albums.first.backup_photos.should_not be_empty
    @member.activity_stream.items.facebook.should_not be_empty
    @member.activity_stream.items.facebook.first.should be_a FacebookActivityStreamItem
  end
  
  before(:each) do
    # Rails env already loaded
    BackupWorker::FacebookStandalone.any_instance.stubs(:load_rails_environment)
    @source = BackupSite::Facebook
  end
  
  describe "initial run" do
    it "should save job run info to backup source job record" do
      setup_db marc_fb_info
      @bw = BackupWorker::FacebookStandalone.new('test')
      @bw.expects(:save_success_data)
      @bw.run(publish_workitem)

      verify_successful_backup(BackupSourceJob.last)
      verify_backup_content_created
    end
  end
  
  describe "subsequent runs" do
    before(:each) do
      load_db 
      @bs.backup_photo_albums.should_not be_empty
      @bw = BackupWorker::FacebookStandalone.new('test')
      @bw.expects(:save_success_data)
    end
    
    it "should not re-save photos" do
      lambda {
        BackupPhotoAlbum.expects(:import).never
        BackupPhotoAlbum.expects(:save_album).never
        @bw.run(publish_workitem)
        verify_successful_backup(BackupSourceJob.last)
      }.should_not change(BackupPhoto, :count)
    end
  
    it "should not re-save activity stream items" do
      lambda {
        @bw.run(publish_workitem)
        verify_successful_backup(BackupSourceJob.last)
      }.should_not change(@member.activity_stream.items, :count)
    end
  end
end