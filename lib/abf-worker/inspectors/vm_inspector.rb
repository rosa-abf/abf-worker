require 'time'

module AbfWorker
  module Inspectors
    class VMInspector
      TIME_LIVING     = 120 # 2 min

      def initialize(worker)
        @worker   = worker
        @thread   = nil
      end

      def run
        @thread = Thread.new do
          sleep TIME_LIVING
          restart_vm
        end
      end

      def stop
        @thread.kill
      end

      private

      def restart_vm
        @worker.logger.info "===> [#{Time.now.utc}] Restart VM..."
        vm_id = @worker.vm.get_vm.id
        system "VBoxManage controlvm #{vm_id} reset"
      end

    end
  end
end