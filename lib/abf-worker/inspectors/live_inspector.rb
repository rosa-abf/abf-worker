require 'time'

module AbfWorker
  module Inspectors
    class LiveInspector
      CHECK_INTERVAL = 60 # 60 sec

      def initialize(worker, time_living)
        @worker       = worker
        @build_id     = @worker.build_id
        @worker_id    = @worker.worker_id
        @kill_at      = Time.now + (time_living.to_i * 60)
        @logger       = @worker.logger
      end

      def run
        @thread = Thread.new do
          while true
            sleep CHECK_INTERVAL
            stop_build if kill_now?
            reboot_vm if reboot?
          end
        end
        @thread.run
      end

      private

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
        @worker.status = AbfWorker::BaseWorker::BUILD_CANCELED
        # Immediately kill child but don't exit
        # Process.kill('USR1', @worker_id)
        iso = @worker.iso
        iso.can_run = false
        iso.script_runner.kill if iso.script_runner
      end

      def reboot_vm
        id = @worker.vm.get_vm.id
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
        @logger.info "-> Check status: #{@build_id}"
        Resque.redis.get("abfworker::iso-worker-#{@build_id}::live-inspector")
      end

    end
  end
end