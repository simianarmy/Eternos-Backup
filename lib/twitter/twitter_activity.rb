# $Id$

# Class for parsing & storing Twitter activity

require RAILS_ROOT + '/lib/activity_stream_proxy'

class TwitterActivity < ActivityStreamProxy    
  # Custom attributes
  attr_reader :id, :created, :message, :author, :activity_type, :attachment
  
  StatusUpdateType  = 'status'
  StatusPostType    = 'post'
  
  # stream_item: Mash object
  def initialize(stream_item)
    DaemonKit.logger.debug "Activity stream => #{stream_item.inspect}"
    super(stream_item)
    
    @id       = stream_item.id
    @created  = Time.parse(stream_item.created_at)
    @message  = stream_item.text
    @author   = stream_item.user.name
    @activity_type     = StatusUpdateType
    process_attachment(stream_item)
  end
  
  private
  
  def process_attachment(attach)
    # Save some attributes from user object
    data.name = attach.user.name
    data.screen_name = attach.user.screen_name
    data.user = nil # Don't save user object - useless info
    # Save original raw data as an attachment
    @attachment = attach
  end
end

      
