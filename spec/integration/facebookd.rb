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
    create_member
  end
  
  def setup_db
    #Member.stubs(:find).returns(@member = mock_model(Member))
    #BackupSite.stubs(:find).returns(@site = mock_model(BackupSite, :name => @source))
    #BackupSource.stubs(:find).returns(@bs = mock_model(BackupSource, :member => @member, :backup_site => @site))
    @member = create_facebook_member
    @site = create_backup_site(:name => 'facebook')
    @bs = create_backup_source(:backup_site => @site, :member => @member)
    @fb_user = FacebookBackup::User.new(1005737378, 'c4c3485e22162aeb0be835bb-1005737378', '6ef09f021c983dbd7d04a92f3689a9a5')
    FacebookBackup::User.stubs(:new).returns(@fb_user)
    #puts "Backup site: #{@site.inspect}"
    #puts "Backup source: #{@bs.inspect}"
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
    bj = BackupSourceJob.last
    bj.created_at.should <= bj.finished_at
    bj.finished_at.should be_close(Time.now, 5)
    bj.status.should == BackupStatus::Success
  end
  
  #     describe "on backup" do
  #       before(:each) do
  #         setup_backup_worker
  #       end
  #       
  #       it "should load rails environment" do
  #         BackupPhotoAlbum.should be_an_instance_of ActiveRecord::Base
  #       end
  #     end
  #   end
end