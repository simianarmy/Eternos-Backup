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
  
  def activity_without_attachment
     {"attachment"=>""}.merge standard_attributes
  end
end
