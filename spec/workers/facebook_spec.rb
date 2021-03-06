# $Id$

LOAD_RAILS=true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/../mq_spec_helper.rb'
require File.dirname(__FILE__) + '/../../lib/workers/base'
require File.dirname(__FILE__) + '/../../lib/workers/facebook_worker'
require File.dirname(__FILE__) + '/../../lib/facebook/backup_user'

module FacebookStreamSpecHelper
  def mock_stream_query_result
    [{"attachment"=>"",
      "actor_id"=>"1005737378",
      "created_time"=>"1242091760",
      "updated_time"=>"1242091760",
      "message"=>"there will be no cake"},
     {"attachment"=>"",
      "actor_id"=>"1005737378",
      "created_time"=>"1242091790",
      "updated_time"=>"1242138789",
      "message"=>"Portal rules"}]
  end
end

describe BackupWorker::Facebook do
  include MQSpecHelper
  include BackupHelperSpecHelper
  
  def setup_backup_worker
    @job = mock('BackupSourceJob')
    @job.stubs(:backup_source).returns(@source = mock_model(BackupSource))
    @job.stubs(:status)
    @source.stubs(:member).returns(@member = mock_model(Member))
    @member.stubs(:facebook_id).returns('100')
    @member.stubs(:facebook_session_key).returns('abc')
    @member.stubs(:facebook_secret_key).returns('shhh')
    FacebookBackup::User.expects(:new).with(@member.facebook_id, @member.facebook_session_key, @member.facebook_secret_key).returns(@fb_user = mock('FacebookUser'))
    @fb_user.expects(:login!)
    stub_logger
    @bw = BackupWorker::Facebook.new(@job)
  end
  
  describe "" do
   
    def mock_album
      a = mock('PhotoAlbum')
      a.stubs(:id => 100, :size => 2, :link => 'link_url', :cover_pid => '10', :name => 'test album',
        :modified => '1244850471', :aid => '1000', :populated => true)
      a
    end
    
    describe "on backup" do
      before(:each) do
        setup_backup_worker
      end
    
      def stub_jobs(*exceptions)
        ([:save_profile, :save_photos, :save_friends, :save_posts] - exceptions).each do |meth|
          @bw.stubs(meth)
        end
      end
      
      describe "logging in to facebook" do
        before(:each) do
          stub_jobs
        end
        
        describe "on failure" do
          it "should save auth error values and stop" do
            @fb_user.stubs(:logged_in? => false, :session => stub(:errors => 'foo'))
            @bw.expects(:save_error)
            @source.expects(:logged_in!).never
            @bw.authenticate.should be_false
          end
        end
      
        describe "on success" do
          it "should save source login time" do
            @fb_user.stubs(:logged_in?).returns(true)
            @source.expects(:logged_in!)
            @bw.authenticate.should be_true
          end
        end
      end
    
      describe "logged in" do
        class FacebookProfile; end
      
        before(:each) do
          @fb_user.stubs(:logged_in?).returns(true)
          @source.expects(:logged_in!)
          @job.stubs(:increment!)
        end
      
        describe "saving profile" do
          before(:each) do
            stub_jobs(:save_profile)
          end
        
          describe "on success" do
            before(:each) do
              @bw.stubs(:valid_profile).returns(true)
            end
          
            it "should send to FacebookProfile object" do
              @fb_user.expects(:profile).returns(@p = {:test => 'foo'})
              @member.expects(:profile).returns(@member_profile = mock('Profile'))
              @member_profile.expects(:update_attribute).with(:facebook_data, @p)
              @bw.expects(:save_error).never
              @bw.run
            end
          end
        end
      
        describe "backup up albums & photos" do
          class BackupPhotoAlbum; end
          
          before(:each) do
            stub_jobs(:save_photos)
            @fb_user.expects(:albums).returns([@album = mock_album])
          end
          
          it "should create album records for each unsaved album" do
            @source.expects(:photo_album).with(@album.id).returns(nil)
            BackupPhotoAlbum.expects(:import).with(@source, @album).returns(@fb_album = mock('BackupPhotoAlbum'))
            @fb_user.expects(:photos).with(@album, {:with_tags => true}).returns(@photos = [mock('FacebookPhoto')])
            @fb_album.expects(:save_photos).with(@photos)
            @bw.run
          end
          
          describe "on existing album" do
            before(:each) do
              @fb_album = mock('BackupPhotoAlbum')
              @source.expects(:photo_album).with(@album.id).returns(@fb_album)
            end
            
            it "should update album if modified" do
              @fb_album.expects(:modified?).with(@album).returns(true)
              @fb_user.expects(:photos).with(@album, {:with_tags => true}).returns(@photos = [mock('FacebookPhoto')])
              @fb_album.expects(:save_album).with(@album, @photos)
              @bw.run
            end
            
            it "should not update album if not modified" do
              @fb_album.expects(:modified?).with(@album).returns(false)
              @fb_album.expects(:save_album).never
              @bw.run
            end
          end
        end
        
        describe "backup wall posts" do
          include FacebookStreamSpecHelper
            
          before(:each) do
            stub_jobs(:save_posts)
          end
          
          it "should save post entries to db" do
            @bw.expects(:save_error).never
            @member.expects(:activity_stream).returns(@stream = mock('ActivityStream'))
            @source.stubs(:backup_site).returns(stub('BackupSite'))
            @stream.stubs(:items).returns(stub('FacebookActivityStreamItems', 
              :facebook => stub('results', :latest => 
                [stub('FacebookActivityStreamItem', :created_at => Date.today)])))
            @fb_user.expects(:wall_posts).with(:start_at => Date.today).returns([])
            #@posts = [mock('FacebookActivity')])
            @bw.run
          end
        end
      end
    end
  end
end

