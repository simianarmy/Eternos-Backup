# $Id$

# Class for parsing & storing Twitter activity

require RAILS_ROOT + '/lib/activity_stream_proxy'

class TwitterActivity < ActivityStreamProxy    
  StatusUpdateType  = 'status'
  StatusPostType    = 'post'
  
  def initialize(stream_item)
    DaemonKit.logger.debug "Activity stream => #{stream_item.inspect}"
    
    self.id       = stream_item.id
    self.created  = Time.parse(stream_item.created_at)
    self.message  = stream_item.text
    self.type     = StatusUpdateType
    process_attachment(stream_item)
  end
  
  private
  
  def process_attachment(data)
    # Save some attributes from user object
    data.name = data.user.name
    data.screen_name = data.user.screen_name
    data.user = nil # Don't save user object - useless info
    self.attachment = data
  end
end

      
