# $Id$

# WARNING: only 1 MQ loop per file!
# See mq_spec_helper for description of awesome bug necessitating this.

require File.dirname(__FILE__) + '/../mq_spec_helper.rb'

AMQP.settings['logging'] = false

# Time to add your specs!
# http://rspec.info/
describe "Message Queues" do
  include MQSpecHelper
  
  it "em-spec sanity check" do
    em do
      start = Time.now

      EM.add_timer(0.5) {
        (Time.now-start).should be_close( 0.5, 0.1 )
        done
      }
    end
  end
  
  describe "direct exchange message passing" do
    it "should process incoming backup jobs as they arrive" do
      @msg = nil
      em do
         mq = MessageQueue.pending_backup_jobs_queue
         mq.publish("FOO FOO")
         mq.subscribe do |msg|
           @msg = msg
           done
         end
      end
      @msg.should == "FOO FOO"
    end
  end
end

