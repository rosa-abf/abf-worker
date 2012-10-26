require 'abf-worker/base_worker'
require 'abf-worker/runners/script'

module AbfWorker
  class IsoWorker < BaseWorker
    extend Runners::Script

    @queue = :iso_worker

    def self.initialize(build_id, os, arch, script_path)
      @build_id = build_id
      @os = os
      @arch = arch
      @script_path = script_path
      @worker_id = ''#Process.ppid
      @vm_name = "#{@os}_#{@arch}_#{@worker_id}"
    end

    def self.perform(build_id, os, arch, script_path)
      initialize build_id, os, arch, script_path
      initialize_vagrant_env
      start_vm
      run_script
      rollback_and_halt_vm
    rescue Resque::TermException
      clean
    rescue Exception => e
      logger.error e.message
      rollback_and_halt_vm
    end

    def self.logger
      @logger || init_logger("abfworker::iso-worker-#{@build_id}")
    end

  end
end