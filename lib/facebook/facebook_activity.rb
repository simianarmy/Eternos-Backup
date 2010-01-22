# $Id$


# Class for parsing & storing FB activitystream data

require RAILS_ROOT + '/lib/activity_stream_proxy'

class FacebookActivity < ActivityStreamProxy
  #attr_reader :author_id, :likers
  
  StatusUpdateType  = 'status'
  StatusPostType    = 'post'
  UnknownType       = 'unknown'
  UnknownAttachment = 'generic'
  AttachmentTypes   = [:photo, :video, :flash, :mp3, :link]
  
  def initialize(stream_item)
    raise ArgumentError unless stream_item.is_a? Hash

    super(stream_item) # parse hash into hashie object

    self.id           = post_id
    self.author_id    = actor_id
    self.created      = created_time.to_i
    self.updated      = updated_time.to_i
    self.source_url   = permalink
    self.likers       = likes.friends.values if likes && (likes.count.to_i > 0)
    self.num_comments = comments.count.to_i rescue 0
    # Erase comments so that the count doesn't get treated as a comment
    self.comments     = nil
    # no idea how to find diff. b/w status updates & posts
    self.activity_type = StatusPostType
    
    process_attachment(attachment)
  end
  
  def has_comments?
    num_comments > 0
  end
  
  # Override equality methods so that we can call uniq on arrays
  def hash
    id.hash
  end
  
  def eql?(comparee)
    self == comparee
  end
    
  # Objects are equal if they have the same
  # unique custom identifier.
  def ==(comparee)
    id == comparee.id
  end
    
  private
  
  # Check http://wiki.developers.facebook.com/index.php/Attachment_%28Streams%29
  # for attachment JSON
  def process_attachment(data)
    if data.kind_of?(Hash) && data.has_key?('media')
      if data['media'].empty?
        self.attachment = data
        self.attachment_type = UnknownAttachment
      else
        # Format attachment hash 
        # Need media.stream_media data if any
        if data['media'].has_key?('stream_media') && data['media']['stream_media'].any?
          self.attachment = data['media']['stream_media']
          self.attachment_type = data['media']['stream_media']['type']
        else
          self.attachment_type = UnknownAttachment
        end
        # Add other attachment attributes
        self.attachment.name        = data['name']
        self.attachment.description = data['description']
        self.attachment.caption     = data['caption']
        self.attachment.properties  = data['properties']
      end
    else
      self.attachment_type = UnknownAttachment
    end
  end
end

      
