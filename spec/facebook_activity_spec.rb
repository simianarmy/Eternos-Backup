# $Id$
LOAD_RAILS = true
require File.dirname(__FILE__) + '/spec_helper'

require File.dirname(__FILE__) + '/facebook_fql_spec_helper'
require File.dirname(__FILE__) + '/../lib/facebook/facebook_activity'

describe FacebookActivity do
  include FacebookFqlSpecHelper
  
  it "should raise error if invalid input on initialization" do
    lambda {
      FacebookActivity.new([1])
    }.should raise_error ArgumentError
  end
  
  describe "on create" do
    before(:each) do
      @activity = FacebookActivity.new @raw_data = activity_without_attachment
    end
    
    it "should be a hashie::mash" do
      @activity.should be_a Hashie::Mash
    end
    
    it "should save required values" do
      @activity.id.should_not be_blank
      @activity.created.to_s.should match(/^\d+$/)
      @activity.updated.to_s.should match(/^\d+$/)
      @activity.message.should == @raw_data['message']
    end
    
    it "should set comments attribute to nil" do
      @activity.comments.should be_nil
    end
    
    it "should know if it has comments" do
      @activity.has_comments?.should == (@raw_data["comments"]["count"].to_i > 0)
    end
    
    it "should create activity object with 'post' type" do
      @activity.attachment_data.should be_empty
      @activity.activity_type.should == FacebookActivity::StatusPostType
    end
    
    it "should save array of comment objects as hashie::mash" do
      @activity.comments = [FacebookComment.new]
      @activity.comments[0].should be_a Hashie::Mash
    end
      
  end
  
  describe "with attachment data" do
    before(:each) do
      @activity = FacebookActivity.new activity_with_attachment
      @type = activity_with_attachment['attachment']['media']['stream_media']['type']
    end
    
    it "should return activity type as post" do
      @activity.activity_type.should == FacebookActivity::StatusPostType
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
    
    describe "with attachment data with extra description attributes" do
      before(:each) do
        @activity = FacebookActivity.new @raw = activity_with_attachment_description
      end
        
      it "should save the extra attributes with the original data" do
        @activity.attachment_data.should be_a Hash
        @activity.attachment_type.should == @raw['attachment']['media']['stream_media']['type']
        @activity.attachment_data['name'].should == @raw['attachment']['name']
        @activity.attachment_data['description'].should == @raw['attachment']['description']
        @activity.attachment_data['caption'].should == @raw['attachment']['caption']
      end
    end
  end
end
    