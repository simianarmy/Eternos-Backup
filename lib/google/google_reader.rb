# $Id$

# Base class for Google data api reader
require 'nokogiri'

class GoogleReader
  @@consecutiveRequestDelaySeconds = 1
  class << self
    attr_reader :consecutiveRequestDelaySeconds 
  end
  
  # Takes an authenticated gdata object
  def initialize(gdata)
    @client = gdata
  end

  # Fetches google data and parses xml
  def parse_url(url)
    Nokogiri::XML(@client.get(url).body)
  end

  def element_value(xml, el)
    if (nodes = xml.xpath(el)).any?
      nodes.first.content
    end
  end
  
  def google_id(xml)
    element_value(xml, 'gphoto:id')
  end
end