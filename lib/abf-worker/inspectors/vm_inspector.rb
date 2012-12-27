require 'time'

module AbfWorker
  module Inspectors
    class VMInspector
      TIME_LIVING     = 120 # 2 min

      def initialize(worker)
        @worker   = worker
        @logger   = @worker.logger
        @kill_at  = Time.now.utc + TIME_LIVING
        @thread   = nil
      end

      def run
        @thread = Thread.new do
          while true
            sleep TIME_LIVING
            restart_vm if @kill_at < Time.now.utc
          end
        end
        @thread.run
      end

      def stop
        @thread.kill
      end

      private

      def restart_vm
        @logger.info "===> [#{Time.now.utc}] Restart VM..."
        vm_id = @worker.vm.get_vm.id
        system "VBoxManage controlvm #{vm_id} reset"
      end

    end
  end
end