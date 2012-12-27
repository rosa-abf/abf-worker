require 'time'

module AbfWorker
  module Inspectors
    class LiveInspector
      CHECK_INTERVAL = 60 # 60 sec

      def initialize(worker, time_living)
        @worker       = worker
        @kill_at      = Time.now + time_living.to_i
      end

      def run
        @thread = Thread.new do
          while true
            begin
              sleep CHECK_INTERVAL
              stop_build if kill_now?
            rescue => e
            end
          end
        end
      end

      private

      def kill_now?
        if @kill_at < Time.now
          @worker.logger.info '===> Time expired, VM will be stopped...'
          return true
        end
        if status == 'USR1'
          @worker.logger.info '===> Received signal to stop VM...'
          true
        else
          false
        end
      end

      def stop_build
        @worker.status = AbfWorker::BaseWorker::BUILD_CANCELED
        runner = @worker.runner
        runner.can_run = false
        runner.script_runner.kill if runner.script_runner
        runner.rollback if runner.respond_to?(:rollback)
      end

      def status
        return nil if @worker.is_a?(AbfWorker::PublishBuildListContainerBaseWorker)
        q = 'abfworker::'
        q << (@worker.is_a?(AbfWorker::IsoWorker) ? 'iso' : 'rpm')
        q << '-worker-'
        q << @worker.build_id.to_s
        q << '::live-inspector'
        Resque.redis.get(q)
      end

    end
  end
end