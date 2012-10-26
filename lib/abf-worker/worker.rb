require 'abf-worker/script_runner'
require 'abf-worker/vm_runner'
require 'vagrant'
require 'sahara'
require 'sahara/command/vagrant'
require 'net/ssh'

module AbfWorker
  class Worker
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
      puts e.message
      rollback_and_halt_vm
    ensure
#      Log4r::Logger.each do |k, v|
#        if k =~ /vagrant/
#          v.outputters = []
#        end
#      end
    end

  end
end