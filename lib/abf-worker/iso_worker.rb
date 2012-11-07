require 'abf-worker/base_worker'
require 'abf-worker/runners/iso'

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
    def self.initialize(options)
      @externalarch = 'x86_64'
      @productname = 'ROSA.2012.LTS'
      @srcpath = options['srcpath']
      @params = options['params']
      @main_script = options['main_script']
      super options['id'], @productname, @externalarch
    end

    def self.perform(options)
      initialize options
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