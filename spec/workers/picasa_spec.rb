# $Id$

LOAD_RAILS=true

require File.dirname(__FILE__) + '/../spec_helper.rb'
require File.dirname(__FILE__) + '/../../lib/workers/base'
require File.dirname(__FILE__) + '/../../lib/workers/picasa_worker'

describe BackupWorker::Picasa do
  include BackupHelperSpecHelper
  include GoogleAuthSpecHelper
  
  before(:each) do
    @job = mock_model(BackupSourceJob)
    @job.stubs(:backup_source).returns(@source = mock_model(BackupSource))

    @source.stubs(:member).returns(@member = mock_model(Member))
    @source.stubs(:auth_token).returns('123')
    @bw = BackupWorker::Picasa.new(@job)
    stub_logger
  end
  
  describe "authenticating" do
    it "should fail with invalid credentials" do
      @bw.authenticate.should be_false
    end
    
    it "should succeed with valid credentials" do
      @source.stubs(:auth_token).returns(valid_google_auth_token)
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
      @source.stubs(:auth_token).returns(valid_google_auth_token)
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
    
    it "should create new backup photo album when album id not found in db" do
      @bw.expects(:convert_albums).returns([@al = PicasaPhotoAlbum.new(@albums.first)])
      @source.expects(:photo_album).with(@al.id).returns(nil)
      BackupPhotoAlbum.expects(:import).with(@source, @al).returns(@backup_album = mock_model(BackupPhotoAlbum))
      @backup_album.expects(:save_photos)
      @bw.run
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