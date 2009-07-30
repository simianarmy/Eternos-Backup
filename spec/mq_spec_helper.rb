# $Id$

# Module holding support methods for MQ specs.  Hilarious bug requires only one
# test using MessageQueue.start per file!! haha!

require File.dirname(__FILE__) + '/../../eternos.com/lib/message_queue'

# Make sure to use this fork for em-spec: git://github.com/danielsdeleo/em-spec.git
require "em-spec/rspec"
require 'active_support'


module MQSpecHelper
  include EM::SpecHelper

  def setup
    MessageQueue.connect_params.each do |key, val|
      AMQP.settings[key] = val
    end
  end

  def stop
    AMQP.stop { MQ.reset; MQ.close; EM.stop }
  end

  def debug_mq_xchange(mq)
    puts "MQ attributes "
    puts "key: #{mq.key}"
    puts "name: #{mq.name}"
    puts "type: #{mq.type}"
  end
end
