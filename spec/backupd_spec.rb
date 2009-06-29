# $Id$

require File.dirname(__FILE__) + '/spec_helper.rb'
require File.dirname(__FILE__) + '/mq_spec_helper.rb'
require File.dirname(__FILE__) + '/../lib/backupd'
require 'openwfe/engine'
require 'activerecord'

class BackupJob; end

AMQP.settings['logging'] = true

# Time to add your specs!
# http://rspec.info/
describe BackupDaemon do
  include MQSpecHelper
  
  describe "on startup" do
    before(:each) do
      setup
      BackupDaemon.any_instance.expects(:load_rails_environment).with('test')
      @bd = BackupDaemon.new('test')
    end

    it "should run mq loop" do
      em do
        MessageQueue.expects(:start)
        @bd.run
       done
      end
    end
      
    describe "in main mq loop" do
      before(:each) do
        @bd.stubs(:simulate_jobs)
      end
      
      # This finally works!
      it "should launch a ruote engine instance with backup job data" do
        MessageQueue.expects(:start).yields
        MessageQueue.expects(:pending_backup_jobs_queue).returns(@q = mock)
        RuoteEngine.expects(:engine).returns(@engine = mock)
        @q.expects(:subscribe).yields(@msg=mock)
        YAML.expects(:load).with(@msg).returns(@payload = {:user_id => 1})
        BackupJob.expects(:create).with(@payload).returns(@bj = stub(:id => 10))
        OpenWFE::LaunchItem.expects(:new).with(RuoteEngine::UserContentBackupProcess).returns(@li = mock)
        @li.expects(:job_id=).with(@bj.id)
        @li.expects(:user_id=).with(@payload[:user_id])
        @li.expects(:target_sites=)
        @engine.expects(:launch).with(@li)
        
        @bd.run
      end
      
      describe "running ruote engine process" do
        def setup_engine
          @engine = RuoteEngine.engine
          @terminated_processes = []
          @engine.get_expression_pool.add_observer(:terminate) do |c, fe, wi|
            @terminated_processes << fe.fei.wfid
          end
        end
              
        before(:each) do
          setup_engine
          @li = OpenWFE::LaunchItem.new(RuoteEngine::UserContentBackupProcess)
          @li.job_id = 100
          @li.user_id = 200    
          @expected_job_info = {
            :status=>"ok", 
            :cancel=>false, 
            :errors=>[], 
            :total_bytes=>(@bytes_backed_up = 1000), 
            :messages=>[], 
            :user_id=>@li.user_id,
            :job_id=>@li.job_id
          }
          ActiveRecord::Base.stubs(:verify_active_connections!)
          BackupJob.expects(:find).with(@li.job_id).returns(@bj = mock)
          @bj.expects(:finish!).with(@expected_job_info)
        end
            
        after(:each) do
          EM.run { AMQP.stop }
        end
        
        it "should work with a single backup source" do
          @li.target_sites = [{:source => 'facebook', :id => 1}]
          lambda {
            fei = @engine.launch(@li)
            run_engine_for_single_source('facebook')
            
            Thread.pass
            sleep(1)
            raise if @terminated_processes.include?(fei.wfid)
            # Can't return from this...
            #@engine.wait_for(fei)
            @ps = @engine.process_status(fei.wfid)
            
            @ps.should_not be_nil
            @ps.errors.should be_empty
          }.should_not raise_error
        end
        
        # it "should work with multiple backup sources" do
        #           @li.target_sites = [{:source => 'gmail', :id => 1}, {:source => 'twitter', :id => 2}]
        #           lambda {
        #             fei = @engine.launch(@li)
        #             run_engine_for_single_source('gmail')
        #             run_engine_for_single_source('twitter')
        #             
        #             Thread.pass
        #             sleep(1)
        #             raise if @terminated_processes.include?(fei.wfid)
        #             # Can't return from this...
        #             #@engine.wait_for(fei)
        #             @ps = @engine.process_status(fei.wfid)
        # 
        #             @ps.should_not be_nil
        #             @ps.errors.should be_empty
        #           }.should_not raise_error
        #         end
        #                        
        
        def run_engine_for_single_source(source)
          # Simulate worker job mq subscriber, using timeout instead of em
          begin
            Timeout::timeout(10) do
              msg = nil
              MessageQueue.backup_worker_subscriber_queue(source).subscribe do |msg| 
                @msg = msg
              end

              loop do
                break unless @msg.nil?
                sleep 1
              end
            end
          end
          wi = OpenWFE::InFlowWorkItem.from_h( ActiveSupport::JSON.decode( @msg ) )
          puts "Got wi #{wi.to_s}"
          wi.attributes['worker'] = {'bytes_backed_up' => @bytes_backed_up}
          puts "Replying to amqp listener on queue: " + wi.attributes['reply_queue']

          q = MQ.queue( wi.attributes['reply_queue'] )
          q.publish( wi.to_h.to_json )
        end
      end
      
      def run_engine_for_multiple_sources(sources)
      end
    end
  end
end
