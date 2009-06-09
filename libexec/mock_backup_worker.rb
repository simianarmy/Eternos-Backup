# $Id$
#
# Helper to simulate backup worker daemons listening on MQ for jobs

require 'rubygems'
require 'mq'
require 'ruote_external_workitem'

# hard-code amqp settings to bypass slow-ass rails env loading
AMQP.start({:user => 'backupd', :pass => 'b4ckUrlIF3', :host => 'localhost', :vhost => '/eternos'}) do
  xchange = MQ.topic("bu_workers")
  MQ.queue('all_workers_queue').bind(xchange, :key => 'backup.#').subscribe do |msg|
    workitem = RuoteExternalWorkitem.parse(msg)
    source = workitem['target']['source']
    puts "A backup job for #{source} received with message: #{workitem.attributes.inspect}"
    
    
    # Simulate backup work
    sleep(2)
    
    # Connect to/create feeback queue
    feedback_q_name = workitem['reply_queue']
    workitem[:worker] = {
      :bytes_backed_up => rand(100) * 1024,
      :status => 200
    }
    puts "Connecting to feedback queue: " + feedback_q_name
    feedback_q = MQ.queue(feedback_q_name) #.bind(MQ.direct("backup_reply"))
    feedback_q.publish(workitem.to_json)
  end
end
  