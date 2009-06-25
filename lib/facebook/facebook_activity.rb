# $Id$


# Class for parsing & storing FB activitystream data

require RAILS_ROOT + '/lib/activity_stream_proxy'

class FacebookActivity < ActivityStreamProxy  
  StatusUpdateType  = 'status'
  StatusPostType    = 'post'
  AttachmentTypes   = [:photo, :video, :flash, :mp3, :link]
  
  def initialize(stream_item)
    raise ArgumentError unless stream_item.is_a? Hash
    @created = stream_item['created_time'].to_i
    @updated = stream_item['updated_time'].to_i
    @message = stream_item['message']
    process_attachment(stream_item['attachment'])
  end
  
  private
  
  def process_attachment(data)
    @type = if data.empty?
      StatusUpdateType
    else
      self.attachment = data['media']['stream_media']
      @attachment_type = data['media']['stream_media']['type']
      StatusPostType
    end
  end
end

      
