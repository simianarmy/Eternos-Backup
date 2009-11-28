# $Id$

require File.dirname(__FILE__) + '/spec_helper.rb'

require File.dirname(__FILE__) + '/../lib/facebook/backup_user'
RAILS_ENV = 'test'

describe FacebookBackup do
  include FacebookUserSpecHelper
    
  describe FacebookBackup::User do  
    describe "on new" do
      it "should require user id and session key on initialize" do
        lambda {
          FacebookBackup::User.new
        }.should raise_error ArgumentError
        
        create_user.should be_an_instance_of FacebookBackup::User
      end
    end
    
    describe "a valid object" do
      before(:each) do
         @user = create_user(100, 'foo')
       end
       
      it "should return a valid session" do
        lambda {
          @user.session.should be_an_instance_of FacebookDesktopApp::Session
        }.should_not raise_error NameError
      end
    
      describe "on login" do
        before(:each) do
        end
    
        it "should return attribute values" do
          @u = create_user(100, 'foo')
          @u.id.should == 100
          @u.session_key.should == 'foo'
        end
    
        it "should fail with invalid session key" do
          @u = create_user
          @u.login!
          @user.should_not be_logged_in
        end
    
        it "should login successfully with valid session & secret keys" do
          lambda {
            @user = create_real_user
            @user.login!
            @user.should be_logged_in
          }.should_not raise_error
        end
      end
      
      describe "logged in" do
        before(:each) do
          @user = create_real_user
          @user.login!
        end
        
        it "should return a user profile hash" do
          p = @user.profile
          p.should_not be_empty
        end  
        
        describe "photo albums" do
          before(:each) do
            @albums = @user.albums
          end
          
          it "should return photo album collection" do
            @albums.should_not be_empty
            @albums.each {|a| a.should be_an_instance_of FacebookPhotoAlbum}
          end
          
          it "should return photos for each album" do
            @user.photos(@albums.first).should_not be_empty            
          end
          
          describe "photo without tags" do
            before(:each) do
              @photos = @user.photos(@albums.first)
              @photo = @photos.first
            end
            
            it "should be an instance of FacebookPhoto" do
              @photo.should be_a FacebookPhoto
            end
            
            it "should have an id and a url" do
              @photo.id.should be_a Integer
              @photo.source_url.should_not be_blank
            end
            
            it "should not have tags saved" do
              @photo.tags.should be_nil
            end
          end
          
          describe "photo with tags" do
            before(:each) do
              @photos = @user.photos(@albums.first, :with_tags => true)
              @photo = @photos.first
            end
            
            it "should save any tags with photo" do
              @photo.tags.should be_a Array
            end
          end
        end
        
        describe "wall posts" do
          before(:each) do
            @posts = @user.wall_posts
          end
          
          it "should return all posts as FacebookActivity objects" do
            @posts.should_not be_empty
            @posts.each {|p| p.should be_an_instance_of FacebookActivity }
          end
          
          it "should return only posts after date specified" do
            @posts = @user.wall_posts(:start_at => Time.now.to_i - 86400)
            @posts.should be_empty
          end
        end
      end
    end
  end
end
    