# $Id$

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/../mq_spec_helper.rb'

require File.dirname(__FILE__) + '/../../lib/workers/facebook_worker'
require 'active_record/base'
require File.dirname(__FILE__) + '/../../../eternos.com/app/models/backup_source'

describe BackupWorker::Facebook do
  include MQSpecHelper

  def setup_backup_worker
    @bw = BackupWorker::Facebook.new(ENV['DAEMON_ENV'])
    @job = mock('BackupSourceJob')
    @job.stubs(:backup_source).returns(@source = mock_model(BackupSource))
    @source.stubs(:member).returns(@member = mock('Member'))
    @member.stubs(:id).returns(1)
    @member.stubs(:facebook_uid).returns('100')
    @member.stubs(:facebook_session_key).returns('abc')
    @member.stubs(:facebook_secret_key).returns('shhh')
    FacebookBackup::User.expects(:new).with(@member.facebook_uid, @member.facebook_session_key, @member.facebook_secret_key).returns(@fb_user = mock('FacebookUser'))
    @fb_user.expects(:login!)
  end
  
  describe "without rails" do
    def mock_album
      a = mock('PhotoAlbum')
      a.stubs(:id => 100, :size => 2, :link => 'link_url', :cover_pid => '10', :name => 'test album',
        :modified => '1244850471', :aid => '1000', :populated => true)
      a
    end
    
    describe "on backup" do
      before(:each) do
        BackupWorker::Facebook.any_instance.expects(:load_rails_environment)
        setup_backup_worker
      end
    
      describe "logging in to facebook" do
        describe "on failure" do
          it "should save auth error values and stop" do
            @fb_user.stubs(:logged_in?).returns(false)
            @bw.expects(:auth_failed).with(@source)
            @source.expects(:logged_in!).never
            @bw.backup(@job)
          end
        end
      
        describe "on success" do
          it "should save source login time" do
            @fb_user.stubs(:logged_in?).returns(true)
            @bw.expects(:auth_failed).never
            @source.expects(:logged_in!)
            @bw.expects(:save_profile)
            @bw.expects(:save_photos)
            @bw.backup(@job)
          end
        end
      end
    
      describe "logged in" do
        class FacebookProfile; end
      
        before(:each) do
          @fb_user.stubs(:logged_in?).returns(true)
          @source.expects(:logged_in!)
        end
      
        describe "saving profile" do
          before(:each) do
          end
        
          describe "on success" do
            before(:each) do
              @bw.stubs(:valid_profile).returns(true)
              @bw.stubs(:save_photos)
            end
          
            it "should send to FacebookProfile object" do
                @fb_user.expects(:profile).returns(@p = {:test => 'foo'})
                @member.expects(:profile).returns(@member_profile = mock('Profile'))
                @member_profile.expects(:update_attribute).with(:facebook_data, @p)
                @bw.expects(:save_error).never
                @bw.backup(@job)
            end
          end
        end
      
        describe "backup up photos" do
          class BackupPhotoAlbum; end
          
          before(:each) do
            @bw.expects(:save_profile)
            @fb_user.expects(:albums).returns([@album = mock_album])
          end
        
          it "should create album records for each unsaved album" do
            @source.expects(:photo_album).with(@album.id).returns(false)
            BackupPhotoAlbum.expects(:import).with(@source, @album)
            @bw.backup(@job)
          end
        end
      end
    end
  end
  
  # describe "with rails" do
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
