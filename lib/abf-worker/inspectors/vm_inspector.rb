require 'time'

module AbfWorker::Inspectors
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
      @worker.logger.log 'Restart VM...'
      vm_id = @worker.vm.get_vm.id
      ps = %x[ ps aux | grep VBox | grep #{vm_id} | grep -v grep | awk '{ print $2 }' ].split("\n").join(' ')
      system "sudo kill -9 #{ps}" unless ps.empty?
      system "VBoxManage startvm #{vm_id}"
    end

  end
end