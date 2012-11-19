require 'time'

module AbfWorker
  module Inspectors
    class LiveInspector
      CHECK_INTERVAL = 60 # 60 sec

      def initialize(worker, time_living)
        @worker       = worker
        @build_id     = @worker.instance_variable_get '@build_id'
        @worker_id    = @worker.instance_variable_get '@worker_id'
        @kill_at      = Time.now + (time_living.to_i * 60)
        @vagrant_env  = @worker.instance_variable_get '@vagrant_env'
        @logger       = @worker.instance_variable_get '@logger'
        init_thread
      end


      private

      def init_thread
        @thread = Thread.new do
          while true
            sleep CHECK_INTERVAL
            stop_build if kill_now?
            reboot_vm if reboot?
          end
        end
        @thread.run
      end

      def kill_now?
        if @kill_at < Time.now
          @logger.info '===> Time expired, VM will be stopped...'
          return true
        end
        if status == 'USR1'
          @logger.info '===> Received signal to stop VM...'
          true
        else
          false
        end
      end

      def stop_build
        @worker.instance_variable_set '@status', AbfWorker::BaseWorker::BUILD_CANCELED
        # Immediately kill child but don't exit
        Process.kill('USR1', @worker_id)
      end

      def reboot_vm
        id = @vagrant_env.vms.first[1].id
        system "VBoxManage controlvm #{id} reset"
      end

      def reboot?
        if status == 'reboot'
          @logger.info '===> Received signal to reboot VM...'
          true
        else
          false
        end
      end

      def status
        Resque.redis.get("abfworker::iso-worker-#{@build_id}::live-inspector")
      end

    end
  end
end