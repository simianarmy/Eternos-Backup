# $Id$

require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/../lib/google/picasa_reader'

describe PicasaReader do
  include GoogleAuthSpecHelper
  
  before(:each) do
    @reader = PicasaReader.new(create_picasa_client.client)
  end
  
  describe "fetching albums" do
    before(:each) do
      @albums = @reader.fetch_albums
    end
    
    it "should return albums collection" do  
      @albums.should_not be_empty
    end
    
    it "should parse album attributes into hash" do
      al = @albums.first
      al.should be_a Hash
      al.album_id.should_not be_blank
      al.published.should_not be_blank
      al.updated.should_not be_blank
      al.title.should_not be_blank
      al.photo_url_s.should_not be_blank
      al.thumbnail_url_s.should_not be_blank
      al.tags.should be_a Array
      al.num_photos.should > 0
    end
  
    describe "with photos" do
      before(:each) do
        @photos = @reader.album_photos(@albums.first.album_id)
      end
      
      it "should be able to fetch collection photos for an album" do
        @photos.size.should == @albums.first.num_photos.to_i
      end
      
      it "should parse photo attributes into hash" do
        @photos.first.should be_a Hash
        p = @photos.first
        p.photo_id.should_not be_blank
        p.photo_url_s.should_not be_blank
        p.thumbnail_url_s.should_not be_blank
        p.tags.should be_a Array
      end
    end
  end
end
