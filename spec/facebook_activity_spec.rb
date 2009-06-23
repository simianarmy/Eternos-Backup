# $Id$

require File.dirname(__FILE__) + '/spec_helper'

require File.dirname(__FILE__) + '/../lib/facebook/facebook_activity'

describe FacebookActivity do
  def activity_with_attachment
    {"attachment"=>
       {"href"=>"http://www.facebook.com/album.php?aid=2025736&amp;id=1005737378",
        "name"=>"Random",
        "icon"=>"http://static.ak.fbcdn.net/images/icons/photo.gif?8:25796",
        "media"=>
         {"stream_media"=>
           {"photo"=>
             {"pid"=>"4319609146905288118",
              "aid"=>"4319609146876815624",
              "height"=>"270",
              "index"=>"1",
              "width"=>"360",
              "owner"=>"1005737378"},
            "href"=>
             "http://www.facebook.com/photo.php?pid=30498230&amp;id=1005737378",
            "src"=>
             "http://photos-g.ak.fbcdn.net/hphotos-ak-snc1/hs101.snc1/4550_1163132390906_1005737378_30498230_3858517_s.jpg",
            "type"=>"photo",
            "alt"=>"Panama to Seattle, about 1/6 of the way"}},
        "properties"=>{}},
      "actor_id"=>"1005737378",
      "created_time"=>"1244850316",
      "updated_time"=>"1244873025",
      "message"=>""}
  end
  
  def activity_without_attachment
     {"attachment"=>"",
      "actor_id"=>"1005737378",
      "created_time"=>"1244867460",
      "updated_time"=>"1244867460",
      "message"=>"facebook.com/simian"}
  end
  
  it "should raise error if invalid input on initialization" do
    lambda {
      FacebookActivity.new([1])
    }.should raise_error ArgumentError
  end
  
  describe "without attachment data" do
    before(:each) do
      @activity = FacebookActivity.new activity_without_attachment
    end
    
    it "should create activity object with 'post' type" do
      @activity.attachment_data.should be_nil
      @activity.message.should_not be_blank
      @activity.type.should == FacebookActivity::StatusUpdateType
    end
  end
  
  describe "with attachment data" do
    before(:each) do
      @activity = FacebookActivity.new activity_with_attachment
      @type = activity_with_attachment['attachment']['media']['stream_media']['type']
    end
    
    it "should return activity type as post" do
      @activity.type.should == FacebookActivity::StatusPostType
    end
    
    it "should parse attachment data into Activity object" do
      @activity.attachment_data.should be_a Hash
    end
  
    it "should return attachment type" do
      @activity.attachment_type.should == @type
    end
    
    it "should save attachment json data" do
      @activity.attachment_data[@type].should_not be_empty
    end
  end
end
    