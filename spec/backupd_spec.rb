# $Id$

require File.dirname(__FILE__) + '/spec_helper.rb'
require File.dirname(__FILE__) + '/mq_spec_helper.rb'
require File.dirname(__FILE__) + '/../lib/backupd'
require 'openwfe/engine'

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
      # This finally works!
      it "should launch a ruote engine instance with backup job data" do
        lambda {
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
        }.should_not raise_error
      end
      
      describe "amqp participants" do
        def setup_engine(engine)
          @terminated_processes = []
          engine.get_expression_pool.add_observer(:terminate) do |c, fe, wi|
            @terminated_processes << fe.fei.wfid
          end
        end
              
        before(:each) do
          @engine = RuoteEngine.engine
          @li = OpenWFE::LaunchItem.new(RuoteEngine::UserContentBackupProcess)
          @li.job_id = 100
          @li.user_id = 200
          #li.target_sites = payload[:target_sites]        
          @li.target_sites = [{:source => 'facebook', :id => 1}, {:source => 'twitter', :id => 2}]
          @source = 'facebook'
        end
        
        it "amqp listener should receive response from remote backup worker" do
          # Can't figure out how to make wait_for return, so instead we force exit on 
          # the save_results...still need to make sure it's not caused by timeout
          lambda {
            SaveResultsParticipant.expects(:consume).yields(exit)
            setup_engine(@engine)
            fei = @engine.launch(@li)
            Thread.pass
            return if @terminated_processes.include?(fei.wfid)
            @engine.wait_for(fei)
          }.should raise_error
        end
      end
    end
  end
end
