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
      @status = AbfWorker::Runners::Iso::BUILD_STARTED
      @srcpath = options['srcpath']
      @params = options['params']
      @main_script = options['main_script']
      super options['id'], options['distrib_type'], options['arch']
      @live_inspector = AbfWorker::Inspectors::LiveInspector.
        new(@build_id, @worker_id, options['time_living'])
    end

    def self.perform(options)
      initialize options
      initialize_vagrant_env
      start_vm
      run_script
      rollback_and_halt_vm { send_results }
    rescue Resque::TermException
      @status = AbfWorker::Runners::Iso::BUILD_FAILED
      clean { send_results }
    rescue Exception => e
      @status = AbfWorker::Runners::Iso::BUILD_FAILED
      logger.error e.message
      rollback_and_halt_vm { send_results }
    end

    def self.logger
      @logger || init_logger("abfworker::iso-worker-#{@build_id}")
    end

    def self.send_results
      results = upload_results_to_file_store.compact
      Resque.push(
        'iso_worker_observer',
        'class' => 'AbfWorker::IsoWorkerObserver',
        'args' => [{
          :id => @build_id,
          :status => @status,
          :results => results
        }]
      )
    end

  end
end