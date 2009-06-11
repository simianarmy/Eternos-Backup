# $Id$

# Monkey-patching ruote-external-work-item gem to only use ActiveSupport's json
# Required due to conflicts b/w AS json & JSON gem

require 'ruote_external_workitem'
 
module RuoteExternalWorkitem
  class << self
    def parse( json_string )
      Base.new( ActiveSupport::JSON.decode( json_string ) )
    end
  end
  
  class Base
    def to_json
      ActiveSupport::JSON.encode(@workitem)
    end
  end
end