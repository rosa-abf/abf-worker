require 'abf-worker/base_worker'
require 'abf-worker/runners/publish_build_list_container'
require 'abf-worker/inspectors/live_inspector'

module AbfWorker
  class PublishBuildListContainerBaseWorker < BaseWorker

    class << self
      attr_accessor :runner

      protected

      def initialize(options)
        @observer_queue = 'publish_build_list_container_observer'
        @observer_class = 'AbfWorker::PublishBuildListContainerObserver'
        super options['id'], options['distrib_type'], options['arch']
        @runner = Runners::PublishBuildListContainer.new(
          self,
          options['container_sha1']
        )
        @vm.share_folder = options['platform_path']
        initialize_live_inspector options['time_living']
      end

      def send_results
        update_build_status_on_abf({:results => @vm.upload_results_to_file_store})
      end

    end

    def self.logger
      @logger || init_logger("abfworker::publish-build-list-container-worker-#{@build_id}")
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