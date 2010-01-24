# $Id$

#LOAD_RAILS=true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/../../lib/workers/base'
require File.dirname(__FILE__) + '/../../lib/workers/picasa_worker'

describe BackupWorker::Picasa do
  include BackupHelperSpecHelper
  include GoogleAuthSpecHelper
  
  before(:all) do
    @auth_token = valid_google_auth_token
  end
  
  before(:each) do
    @job = mock_model(BackupSourceJob)
    @job.stubs(:backup_source).returns(@source = create_backup_source)
    @source.stubs(:auth_token).returns(@auth_token)
    @bw = BackupWorker::Picasa.new(@job)
    stub_logger
  end
  
  describe "authenticating" do
    it "should fail with invalid credentials" do
      @source.stubs(:auth_token).returns('bad')
      @bw.authenticate.should be_false
    end
    
    it "should succeed with valid credentials" do
      @bw.expects(:save_error).never
      @bw.authenticate.should be_true
    end
    
    it "should not raise an exception even if authenticating client does" do
      GoogleBackup::Auth::Picasa.expects(:new).raises Exception
      @bw.expects(:save_error)
      lambda {
        @bw.authenticate
      }.should_not raise_error
    end
  end
  
  describe "saving albums" do
    before(:each) do
      @bw.authenticate
      @reader = PicasaReader.new @bw.picasa_client.client
      @albums = @reader.fetch_albums
    end

    it "should convert albums objects into PicasaPhotoAlbum objects" do
      @picasa_albums = @bw.send(:convert_albums, @albums)
      @picasa_albums.size.should == @albums.size
      @picasa_albums.each {|p| p.should be_a PicasaPhotoAlbum }
      @picasa_albums.each_with_index {|al, i| al.id.should == @albums[i].album_id}
    end
    
    it "should convert photo objects into PicasaPhoto objects" do
      photos = @bw.send(:convert_photos, @reader.album_photos(@albums.first.album_id))
      photos.should_not be_empty
      photos.each {|p| p.should be_a PicasaPhoto }
    end
    
    it "should search for each photo album ar object using xml album id" do
      @albums.each do |al|
        @source.expects(:photo_album).with(al.album_id).returns(stub('pa', :modified? => false))
      end
      @bw.run
    end
    
    describe "a new album" do
      before(:each) do
        @bw.stubs(:convert_albums).returns([@al = PicasaPhotoAlbum.new(@albums.first)])
        @source.expects(:photo_album).with(@al.id).returns(nil)
      end

      describe "with photos" do
        def create_picasa_photo
          PicasaPhoto.new(Hashie::Mash.new(:photo_id => "5212280305690160738", 
            :photo_url_s => @albums.first.photo_url_s,
            :published => DateTime.now.to_s, 
            :tags => ['foo'], 
            :title => 'some.jpg', 
            :updated => DateTime.now.to_s))
        end
        
        before(:each) do
          @bw.stubs(:convert_photos).returns([@photo = create_picasa_photo])
        end
        
        it "should create a new backup photo album record" do
          lambda {
            @bw.run
            }.should change(BackupPhotoAlbum, :count).by(1)
        end

        it "should save photos with album" do 
          lambda {
            @bw.run
          }.should change(BackupPhoto, :count).by(1)
        end
        
        it "new backup photo album attributes should match google's data" do
          @bw.run
          @album = BackupPhotoAlbum.last
          @album.backup_source.should == @source
          @album.source_album_id.should == @al.id
          @album.cover_id.should == @photo.id
          @album.size.should == @al.size
          @album.name.should == @al.title
          @album.description.should == @al.summary
          @album.created_at.should == @al.published_at
          @album.modified.should == @al.modified.to_s
          @album.location.should == @al.location
        end
        
        it "new backup photo attributes should match google's data" do
          @bw.run
          album = BackupPhotoAlbum.last
          photo = BackupPhoto.last
          photo.backup_photo_album.should == album
          photo.source_photo_id.should == @photo.id
          photo.added_at.should == @photo.added_at
          photo.modified_at.should == @photo.modified_at
          photo.caption.should == @photo.summary
          photo.tags.should == @photo.tags
          photo.title.should == @photo.title
        end
      end
    end
      
    it "should update existing backup photo albums if modified" do
      @bw.expects(:convert_albums).returns([@al = PicasaPhotoAlbum.new(@albums.first)])
      @source.expects(:photo_album).with(@al.id).returns(@pa = mock_model(BackupPhotoAlbum))
      @pa.stubs(:modified?).returns(true)
      @pa.expects(:update_album)
      @bw.run
    end
  end
end