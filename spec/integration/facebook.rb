# $Id$

LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/integration_spec_helper'
require File.dirname(__FILE__) + '/../../lib/workerd'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/facebookd_test.log')

describe BackupWorker::Facebook do
  include IntegrationSpecHelper
  @@member_id = 0
  
  def marc_fb_info
    {:id => 1005737378,
      :session =>  '5dcf12fae9643866f7a65388-1005737378', 
      :secret => 'af1504279826a5737c15fd6fb873353b'}
  end
  
  def create_facebook_member(fb_info)
    member = create_member
    member.update_attributes(:first_name => "facebook test - #{fb_info[:id]}", 
      :facebook_id => fb_info[:id])
    member.set_facebook_session_keys(fb_info[:session], fb_info[:secret])
    member.create_profile
    member.create_activity_stream
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
    @bs = @member.backup_sources.facebook.first
  end
  
  def mock_facebook_user
    @fb_user = FacebookBackup::User.stubs(:new).returns(mock('FacebookBackup::User'))
  end
  
  def verify_backup_content_created
    @member.profile.should be_a Profile
    @member.profile.reload.facebook_data[:birthday].should =~ /\d/
    fb_content = @member.profile.facebook_content
    fb_content.should be_a FacebookContent
    fb_content.friends.should be_a Array
    fb_content.friends.should have_at_least(1).things
    fb_content.groups.should be_a Array # Can be empty, just not nil
    @bs.backup_photo_albums.should have_at_least(1).things
    @bs.backup_photo_albums.first.backup_photos.should have_at_least(1).things
    @member.activity_stream.items.facebook.should have_at_least(1).things
    @member.activity_stream.items.facebook.first.should be_a FacebookActivityStreamItem
  end
    
  before(:all) do
    # Rails env already loaded
    overload_amqp
    BackupSourceJob.stub_chain(:backup_source_id_eq, :newest).returns(nil)
    @source = BackupSite::Facebook
    test_json_conflict
    setup_db marc_fb_info
    @worker = create_worker_queue
    @worker.run
  end
      
  describe "on backup" do
    before(:each) do
      mock_queues
    end
    
    it "should save job run info to backup source job record on success" do      
      publish_job(@source)
      verify_successful_backup(BackupSourceJob.last)
      verify_backup_content_created
    end
    
    with_transactional_fixtures(:off) do
      it "should not re-save the same photos" do
        BackupWorker::Facebook.actions = [:photos]
        publish_job(@source)
        reset_broker
        lambda {
          BackupPhotoAlbum.expects(:import).never
          BackupPhotoAlbum.expects(:save_album).never
          publish_job(@source)
        }.should_not change(BackupPhoto, :count)
      end
    
      it "should not create duplicate activity stream items" do
        BackupWorker::Facebook.actions = [:posts]
        publish_job(@source)
        reset_broker
        lambda {
          FacebookActivityStreamItem.expects(:create_from_proxy!).never
          publish_job(@source)
        }.should_not change(ActivityStreamItem, :count)
      end
    end
  end
end