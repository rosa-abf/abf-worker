require 'abf-worker/runners/rpm'
require 'abf-worker/inspectors/live_inspector'

module AbfWorker
  class RpmWorker < BaseWorker
    @queue = :rpm_worker

    class << self
      attr_accessor :runner

      def logger
        @logger || init_logger("abfworker::rpm-worker-#{@build_id}")
      end

      protected

      # Initialize a new RPM worker.
      # @param [Hash] options The hash with options
      def initialize(options)
        @observer_queue = 'rpm_worker_observer'
        @observer_class = 'AbfWorker::RpmWorkerObserver'
        super options
        @runner = AbfWorker::Runners::Rpm.new(self, options)
        initialize_live_inspector options['time_living']
      end

      def send_results
        sha1_s  = @runner.packages.map{ |p| p['sha1'] }
        results = @vm.upload_results_to_file_store
        results.select!{ |r| !sha1_s.include?(r[:sha1]) } unless sha1_s.empty?
        update_build_status_on_abf({
          :results => results,
          :packages => @runner.packages
        })
      end

    end

  end

  class RpmWorkerDefault < RpmWorker
    @queue = :rpm_worker_default
  end
end