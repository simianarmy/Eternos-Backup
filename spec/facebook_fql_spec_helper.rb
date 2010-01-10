# $Id$

# Facebook FQL mock object for specs

module FacebookFqlSpecHelper
  def standard_attributes
    {"post_id" => "666_888",
    "actor_id"=>"1005737378",
    "created_time"=>"1244850316",
    "updated_time"=>"1244873025",
    "message"=>"hello",
    "comments" => {"count" => '1'},
    "likes" => {"count" => '0'},
    "attribution" => "",
    "permalink" => "http://facebook.com/permalink"}
  end
  
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
        "properties"=>{}}
    }.merge(standard_attributes)
  end
  
  def activity_with_attachment_description
    {"attachment"=>
     {"href"=>
       "http://apps.facebook.com/dailyhoroscopeapp/index.php?r=16127&scid=1127",
      "name"=>"Daily Aries Horoscope",
      "fb_object_type"=>{},
      "fb_object_id"=>{},
      "icon"=>
       "http://photos-g.ak.fbcdn.net/photos-ak-sf2p/v43/186/42438882966/app_2_42438882966_2713.gif",
      "media"=>
       {"stream_media"=>
         {"href"=>
           "http://apps.facebook.com/dailyhoroscopeapp/index.php?r=16127&scid=1127",
          "src"=>
           "http://platform.ak.fbcdn.net/www/app_full_proxy.php?app=42438882966&v=1&size=z&cksum=ab9ad2a9804452388d2e8684332da954&src=http%3A%2F%2Fhoroscopeimages.talltreegames.com%2Fhoroscope%2Fimages%2Fset1%2Faries.jpg",
          "type"=>"link"}},
      "description"=>
       "People or situations could seem a little odd to you today, Aries. Even still this does not spoil the flow of business and such during the day, because it is an omen; you need to capitalize on your own uniqueness. Even when this uniqueness is about an impe...",
      "caption"=>"Chris's Daily Aries Horoscope",
      "properties"=>{}}
    }.merge(standard_attributes)
  end
  
  def activity_without_attachment
     {"attachment"=>""}.merge standard_attributes
  end
end
