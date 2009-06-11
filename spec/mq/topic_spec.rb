# $Id$

# WARNING: only 1 MQ loop per file!
# See mq_spec_helper for description of awesome bug necessitating this.

require File.dirname(__FILE__) + '/../mq_spec_helper.rb'

AMQP.settings['logging'] = false


describe "MQ Topic exchanges message passing" do
  include MQSpecHelper
  
  describe "message passing" do 
    before(:all) do
      setup
    end
    
    it "should satisfy sanity check for amqp topic message passing" do
      @msg = nil
      
      em do
        @source = 'facebook'
        MessageQueue.backup_worker_topic.publish('FOO FOO', 
          :key => MessageQueue.backup_worker_topic_route(@source))
        
        MessageQueue.backup_worker_subscriber_queue(@source).subscribe do |msg|
          msg.should == 'FOO FOO'
          done
        end
      end
    end
  end
end
