# AMQP class patch to reprocess unacked messages

class MQ
  class Queue
    def recover(options = {}) 
      @mq.callback do 
        @mq.send(AMQP::Protocol::Basic::Recover.new({:requeue => false}.merge(options))) 
      end 
      self 
    end
  end
end
          