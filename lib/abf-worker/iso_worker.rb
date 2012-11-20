require 'abf-worker/base_worker'
require 'abf-worker/runners/iso'
require 'abf-worker/inspectors/live_inspector'

module AbfWorker
  class IsoWorker < BaseWorker
    @queue = :iso_worker

    class << self
      attr_accessor :observer_queue,
                    :observer_queue,
                    :live_inspector,
                    :iso

      protected

      # Initialize a new ISO worker.
      # @param [Hash] options The hash with options:
      # - [Integer] id The identifier of current build
      # - [String] srcpath The path for build scripts
      # - [String] params The params for running script
      # - [String] main_script The main script
      # - [String] time_living The max time for building (in minutes)
      # - [String] arch The arch of VM
      # - [String] distrib_type The type of product
      def initialize(options)
        @observer_queue = 'iso_worker_observer'
        @observer_class = 'AbfWorker::IsoWorkerObserver'
        super options['id'], options['distrib_type'], options['arch']
        @iso = Runners::Iso.new(
          self,
          options['srcpath'],
          options['params'],
          options['main_script']
        )
      end

      def initialize_live_inspector(options)
        @live_inspector = AbfWorker::Inspectors::LiveInspector.
          new(self, options['time_living'])
        @live_inspector.run
      end


      def send_results
        update_build_status_on_abf({:results => @iso.upload_results_to_file_store})
      end

    end

    def self.logger
      @logger || init_logger("abfworker::iso-worker-#{@build_id}")
    end

    def self.perform(options)
      initialize options
      @vm.initialize_vagrant_env
      initialize_live_inspector options
      @vm.start_vm
      @iso.run_script
      @vm.rollback_and_halt_vm { send_results }
    rescue Resque::TermException
      @status = BUILD_FAILED if @status != BUILD_CANCELED
      @vm.clean { send_results }
    rescue Exception, Error => e
      @status = BUILD_FAILED if @status != BUILD_CANCELED
      logger.error e.message
      @vm.rollback_and_halt_vm { send_results }
    end

  end
end