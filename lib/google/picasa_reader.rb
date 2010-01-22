# $Id$

# Class for Picasa Data API read operations
#require File.join(RAILS_ROOT, 'lib', 'picasa_photo_album')
require File.join(File.dirname(__FILE__), 'google_reader')
require 'hashie'

class PicasaReader < GoogleReader
  FeedListRequestUrl  = 'http://picasaweb.google.com/data/feed/api/user/default'
  PhotoListRequestUrl = 'http://picasaweb.google.com/data/feed/api/user/default/albumid/#ALBUMID'
  
  def fetch_albums
    fetch_albums_xml.css('entry').map{ |al| create_album_from_xml(al) }
  end
  
  def album_photos(album_id)
    fetch_album_photos_xml(album_id).css('entry').map{ |photo| create_photo_from_xml(photo) }
  end
  
  def account_title
    xml = parse_url(FeedListRequestUrl)
    element_value(xml, 'author/uri')
  end
  
  protected
  
  def fetch_albums_xml
    @albums_xml ||= parse_url(FeedListRequestUrl)
  end
  
  def fetch_album_photos_xml(album_id)
    url = PhotoListRequestUrl.dup
    url['#ALBUMID'] = album_id
    parse_url(url)
  end
  
  def fetch_album_xml(album_id)
    @albums_xml.xpath("//xmlns:entry[gphoto:id='#{album_id}']").first
  end
  
  # Creates Hashie object from album xml data
  def create_album_from_xml(xml)
    returning(Hashie::Mash.new) do |album|
      read_common_attributes(xml, album)
      album.album_id    = google_id(xml)
      album.num_photos  = element_value(xml, 'gphoto:numphotos').to_i
      album.location    = element_value(xml, 'gphoto:location')
    end
  end
  
  # Creates Hashie object from photo xml data
  def create_photo_from_xml(xml)
    returning(Hashie::Mash.new) do |photo|
      read_common_attributes(xml, photo)
      photo.photo_id    = google_id(xml)
      photo.description = element_value(xml, 'media:group/media:description')
      # Save optional geo coordinates
      photo.geopoint    = element_value(xml, 'georss:where/gml:pos')
    end
  end
  
  def read_common_attributes(xml, object)
    object.published   = element_value(xml, 'xmlns:published')
    object.updated     = element_value(xml, 'xmlns:updated')
    object.title       = element_value(xml, 'xmlns:title')
    object.summary     = element_value(xml, 'xmlns:summary')
    object.tags        = parse_keywords(element_value(xml, 'media:group/media:keywords'))
    # url attributes need _s postfix to prevent ActionController routing method calls
    object.photo_url_s      = xml.xpath('media:group/media:content').first['url']
    object.thumbnail_url_s  = xml.xpath('media:group/media:thumbnail').first['url']
  end
  
  # Parse keywords string into tags array
  def parse_keywords(keywords)
    keywords ? keywords.split(',') : []
  end
end
