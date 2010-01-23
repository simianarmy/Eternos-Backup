# $Id$

LOAD_RAILS = true

require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/integration_spec_helper'
require File.dirname(__FILE__) + '/../../lib/workerd'

DaemonKit.logger = Logger.new(File.dirname(__FILE__) + '/../../log/picasa_test.log')

describe BackupWorker::Picasa do
  include IntegrationSpecHelper
  @@member_id = 0
  
  def google_auth_token
    'CPTLiMT9GRDmgNn0_P____8B'
  end
  
  def setup_db
    @member = create_member
    @@member_id = @member.id
    @site = create_backup_site(:name => BackupSite::Picasa)
    setup_backup_source(BackupSite::Picasa, nil, google_auth_token)
  end
  
  def load_db(user_id=@@member_id)
    @member = Member.find(user_id)
    @bs = @member.backup_sources.picasa.first
  end
  
  def verify_backup_content_created
    @bs.backup_photo_albums.should have_at_least(1).things
    @bs.backup_photo_albums.first.backup_photos.should have_at_least(1).things
  end
    
  before(:all) do
    # Rails env already loaded
    overload_amqp
    BackupSourceJob.stub_chain(:backup_source_id_eq, :newest).returns(nil)
    @source = BackupSite::Picasa
    test_json_conflict
    setup_db
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
    
    describe "on authentication failure" do
      it "should save authentication error message" do
        PicasaWebAccount.any_instance.stubs(:auth_token).returns('oh no')
        @worker.expects(:run).never
        publish_job(@source)
        j = BackupSourceJob.last
        j.error_messages.to_s.should =~ /Token invalid/i
      end
    end
    
    with_transactional_fixtures(:off) do
      it "should not re-save the same photos" do
        publish_job(@source)
        reset_broker
        lambda {
          BackupPhotoAlbum.expects(:import).never
          BackupPhotoAlbum.expects(:save_album).never
          publish_job(@source)
        }.should_not change(BackupPhoto, :count)
      end
    end
  end
end