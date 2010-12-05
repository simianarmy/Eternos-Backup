# $Id$

# Class for parsing & storing FB activitystream data

require RAILS_ROOT + '/lib/activity_stream_proxy'

class FacebookActivity < ActivityStreamProxy
  # Custom attributes
  attr_reader :id, :author_id, :created, :updated, :source_url, :activity_type, :attachment, :attachment_type, :comments
  
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
    @num_likers   = data.likes.count.to_i rescue 0
    @num_comments = data.comments.count.to_i rescue 0
    # Erase comments so that the count doesn't get treated as a comment
    @comments     = nil
    @likers       = nil
    # no idea how to find diff. b/w status updates & posts
    @activity_type = StatusPostType
    @attachment   = nil
    
    process_attachment(data.attachment)
  end
  
  def has_comments?
    @num_comments > 0
  end
  
  def has_likers?
    @num_likers > 0
  end
  
  def object_id
    parts = id.split('_')
    (parts.size == 2) ? parts[1] : id
  end
  
  # Returns unique id for this event
  def guid
    [id, author_id, created, source_url].join
  end
  
  # Override equality methods so that we can call uniq on arrays
  def hash
    guid.hash
  end
  
  def eql?(comparee)
    self == comparee
  end
    
  # Objects are equal if they have the same
  # unique custom identifier.
  def ==(comparee)
    guid == comparee.guid
  end
  
  # Converts and saves array of comment objects
  def comments=(comms)
    # Convert to final proxy object before saving
    return if comms.nil?
    @comments = comms.map { |c| FacebookProxyObjects::FacebookObjectComment.new(c) }
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
        # Old Facebooker response hash format
        media = nil
        if Facebooker::VERSION::STRING <= "1.0.62"
          if attach['media'].has_key?('stream_media') && attach['media']['stream_media'].any?
            media = attach['media']['stream_media']
          end
        else
          media = attach.media[0] # Can be more than one now?
        end
        
        if media
          @attachment = media
          @attachment_type = media['type']
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

      
