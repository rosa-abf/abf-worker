require 'abf-worker/script_runner'
require 'abf-worker/vm_runner'
require 'vagrant'
require 'sahara'
require 'sahara/command/vagrant'
require 'net/ssh'
require 'log4r'

module AbfWorker
  class Worker
    include Log4r
    extend VmRunner
    extend ScriptRunner

    @queue = :worker

    def self.initialize(build_id, os, arch, script_path)
      @build_id = build_id
      @os = os
      @arch = arch
      @script_path = script_path
      @worker_id = ''#Process.ppid
      @vm_name = "#{@os}_#{@arch}_#{@worker_id}"

      logger_name = "abfworker::build-worker-#{@build_id}"
      @logger = Log4r::Logger.new logger_name, ALL
      @logger.outputters << Log4r::Outputter.stdout
      @logger.outputters << Log4r::FileOutputter.
        new(logger_name, :filename =>  "logs/build-#{@build_id}")
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
      @logger.error e.message
      rollback_and_halt_vm
    end

  end
end