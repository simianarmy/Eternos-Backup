# $Id$

# Tests backup engine <-> worker message loop

# WARNING: only 1 MQ loop per file!
# See mq_spec_helper for description of awesome bug necessitating this.

require File.dirname(__FILE__) + '/../mq_spec_helper.rb'

AMQP.settings['logging'] = false


describe "MQ backup engine to worker and back message passing" do
  include MQSpecHelper
  
  describe "" do 
    before(:all) do
      setup
      @source = 'facebook'
      @feedback_queue = MessageQueue::Backup::FeedbackQueue
    end
    
    it "should receive response from worker after sending it a message" do
      em do
        MessageQueue.backup_worker_topic.publish('FOO FOO', 
          :key => MessageQueue.backup_worker_topic_route(@source))
        
        MessageQueue.backup_worker_subscriber_queue(@source).subscribe do |msg|
          msg.should == 'FOO FOO'
          
          puts "Connecting to feedback queue: " + @feedback_queue
          MQ.queue(@feedback_queue).publish('FA FA')
        end
        
        MQ.queue(@feedback_queue).subscribe do |msg|
          msg.should == 'FA FA'
          done
        end
      end
    end
  end
end
