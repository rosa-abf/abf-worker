require 'abf-worker/base_worker'
require 'abf-worker/runners/rpm'
require 'abf-worker/inspectors/live_inspector'

module AbfWorker
  class RpmWorker < BaseWorker
    @queue = :rpm_worker

    class << self
      attr_accessor :observer_queue,
                    :observer_queue,
                    :rpm

      protected

      # Initialize a new RPM worker.
      # @param [Hash] options The hash with options
      def initialize(options)
        @observer_queue = 'rpm_worker_observer'
        @observer_class = 'AbfWorker::RpmWorkerObserver'
        super options['id'], options['distrib_type'], options['arch']
        @rpm = Runners::Rpm.new(
          self,
          options['git_project_address'],
          options['commit_hash'],
          options['build_requires'],
          options['include_repos_hash'],
          options['bplname']
        )
      end

      def send_results
        update_build_status_on_abf({:results => @vm.upload_results_to_file_store})
      end

    end

    def self.logger
      @logger || init_logger("abfworker::rpm-worker-#{@build_id}")
    end

    def self.perform(options)
      initialize options
      @vm.initialize_vagrant_env
      initialize_live_inspector options['time_living']
      @vm.start_vm
      @rpm.run_script
      @vm.rollback_and_halt_vm { send_results }
    rescue Resque::TermException
      @status = BUILD_FAILED if @status != BUILD_CANCELED
      @vm.clean { send_results }
    rescue => e
      @status = BUILD_FAILED if @status != BUILD_CANCELED
      logger.error e.message
      logger.error e.backtrace.join("\n")
      @vm.rollback_and_halt_vm { send_results }
    end

  end
end