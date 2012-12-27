require 'abf-worker/base_worker'
require 'abf-worker/runners/rpm'
require 'abf-worker/inspectors/live_inspector'

module AbfWorker
  class RpmWorker < BaseWorker
    @queue = :rpm_worker

    class << self
      attr_accessor :runner

      protected

      # Initialize a new RPM worker.
      # @param [Hash] options The hash with options
      def initialize(options)
        @observer_queue = 'rpm_worker_observer'
        @observer_class = 'AbfWorker::RpmWorkerObserver'
        super options
        @runner = Runners::Rpm.new(
          self,
          options['git_project_address'],
          options['commit_hash'],
          options['build_requires'],
          options['include_repos'],
          options['bplname'],
          options['user']
        )
        initialize_live_inspector options['time_living']
      end

      def send_results
        update_build_status_on_abf({
          :results => @vm.upload_results_to_file_store,
          :packages => @runner.packages
        })
      end

    end

    def self.logger
      @logger || init_logger("abfworker::rpm-worker-#{@build_id}")
    end

    def self.perform(options)
      initialize options
      @vm.initialize_vagrant_env
      @vm.start_vm
      @runner.run_script
      @vm.rollback_and_halt_vm { send_results }
    rescue Resque::TermException
      @status = BUILD_FAILED if @status != BUILD_CANCELED
      @vm.clean { send_results }
    rescue => e
      @status = BUILD_FAILED if @status != BUILD_CANCELED
      print_error(e)
      @vm.rollback_and_halt_vm { send_results }
    end

  end
end