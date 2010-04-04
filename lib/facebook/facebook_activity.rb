# $Id$

# Class for parsing & storing FB activitystream data

require RAILS_ROOT + '/lib/activity_stream_proxy'

class FacebookActivity < ActivityStreamProxy
  # Custom attributes
  attr_reader :id, :author_id, :created, :updated, :source_url, :likers, :num_comments, :activity_type, :attachment, :attachment_type
  
  StatusUpdateType  = 'status'
  StatusPostType    = 'post'
  UnknownType       = 'unknown'
  UnknownAttachment = 'generic'
  AttachmentTypes   = [:photo, :video, :flash, :mp3, :link]
  
  def initialize(stream_item)
    raise ArgumentError unless stream_item.is_a? Hash
    super(stream_item) # parse stream data hash into hashie object
    
    # Setup aliases
    @id           = data.post_id
    @author_id    = data.actor_id
    @created      = data.created_time.to_i
    @updated      = data.updated_time.to_i
    @source_url   = data.permalink
    @likers       = data.likes.friends.values if data.likes && (data.likes.count.to_i > 0)
    @num_comments = data.comments.count.to_i rescue 0
    # Erase comments so that the count doesn't get treated as a comment
    @comments     = nil
    # no idea how to find diff. b/w status updates & posts
    @activity_type = StatusPostType
    @attachment   = nil
    process_attachment(data.attachment)
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
  def process_attachment(attach)
    #DaemonKit.logger.debug "Parsing FB attachment data => #{attach.inspect}"
    
    if attach.kind_of?(Hash) && attach.has_key?('media')
      if attach['media'].empty?
        @attachment = attach
        @attachment_type = UnknownAttachment
      else
        # Format attachment hash 
        # Need media.stream_media data if any
        if attach.media.stream_media
#        if attach['media'].has_key?('stream_media') && attach['media']['stream_media'].any?
          @attachment = attach['media']['stream_media']
          @attachment_type = attach['media']['stream_media']['type']
        else
          @attachment = Hashie::Mash.new
          @attachment_type = UnknownAttachment
        end
        # Add other attachment attributes
        @attachment.name        = attach['name']
        @attachment.description = attach['description']
        @attachment.caption     = attach['caption']
        @attachment.properties  = attach['properties']
      end
      DaemonKit.logger.debug "Parsed FB attachment type => #{@attachment_type}"
    else
      @attachment_type = UnknownAttachment
    end
  end
end

      
