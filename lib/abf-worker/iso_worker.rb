require 'abf-worker/base_worker'
require 'abf-worker/runners/iso'
require 'abf-worker/inspectors/live_inspector'

module AbfWorker
  class IsoWorker < BaseWorker
    extend Runners::Iso
    @queue = :iso_worker

    # Initialize a new ISO worker.
    # @param [Hash] options The hash with options:
    # - [Integer] id The identifier of current build
    # - [String] srcpath The path for build scripts
    # - [String] params The params for running script
    # - [String] main_script The main script
    # - [String] time_living The max time for building (in minutes)
    # - [String] arch The arch of VM
    # - [String] distrib_type The type of product
    def self.initialize(options)
      @observer_queue = 'iso_worker_observer'
      @observer_class = 'AbfWorker::IsoWorkerObserver'
      @srcpath = options['srcpath']
      @params = options['params']
      @main_script = options['main_script']
      super options['id'], options['distrib_type'], options['arch']
    end

    def self.initialize_live_inspector(options)
      @live_inspector = AbfWorker::Inspectors::LiveInspector.
        new(@build_id, @worker_id, options['time_living'], @vagrant_env, logger)
    end

    def self.perform(options)
      initialize options
      initialize_vagrant_env
      initialize_live_inspector options
      start_vm
      run_script
      rollback_and_halt_vm { send_results }
    rescue Resque::TermException
      @status = BUILD_FAILED
      clean { send_results }
    rescue Exception => e
      @status = BUILD_FAILED
      logger.error e.message
      rollback_and_halt_vm { send_results }
    end

    def self.logger
      @logger || init_logger("abfworker::iso-worker-#{@build_id}")
    end

    def self.send_results
      update_build_status_on_abf({:results => upload_results_to_file_store})
    end

  end
end