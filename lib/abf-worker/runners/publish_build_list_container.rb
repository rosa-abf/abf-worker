require 'abf-worker/exceptions/script_error'
require 'digest/md5'
require 'forwardable'

module AbfWorker
  module Runners
    class PublishBuildListContainer
      extend Forwardable

      FILE_STORE = 'http://file-store.rosalinux.ru/api/v1/file_stores/'
      PUBLISH_BUILD_LIST_SCRIPT_PATH = 'https://abf.rosalinux.ru/avokhmin/publish-build-list-script/archive/avokhmin-publish-build-list-script-master.tar.gz'
      attr_accessor :script_runner,
                    :can_run

      def_delegators :@worker, :logger

      def initialize(worker, options)
        @worker = worker
        @container_sha1 = options['container_sha1']
        @platform = options['platform']
        @repository_name = options['repository_name']
        @can_run = true
      end

      def run_script
        @script_runner = Thread.new do
          if @worker.vm.communicator.ready?
            prepare_script
            logger.info '==> Run script...'

            command = []
            command << 'cd publish-build-list-script/;'
            command << "RELEASED=#{@platform['released']}"
            command << "REPOSITORY_NAME=#{@repository_name}"
            command << "ARCH=#{@worker.vm.arch}"
            command << "TYPE=#{@worker.vm.os}"
            command << '/bin/bash'
            # command << "build.#{@worker.vm.os}.sh"
            command << 'build.sh'
            critical_error = false
            begin
              @worker.vm.execute_command command.join(' ')
              logger.info '==>  Script done with exit_status = 0'
              @worker.status = AbfWorker::BaseWorker::BUILD_COMPLETED
            rescue AbfWorker::Exceptions::ScriptError => e
              logger.info "==>  Script done with exit_status != 0. Error message: #{e.message}"
              @worker.status = AbfWorker::BaseWorker::BUILD_FAILED
            rescue => e
              @worker.print_error e
              @worker.status = AbfWorker::BaseWorker::BUILD_FAILED
              critical_error = true
            end
            save_results
            rollback if critical_error
          end
        end
        @script_runner.join if @can_run
      end

      def rollback
      end

      private

      def save_results
        logger.info "==> Downloading results...."
        port = @worker.vm.get_vm.config.ssh.port
        system "scp -r -o 'StrictHostKeyChecking no' -i keys/vagrant -P #{port} vagrant@127.0.0.1:/home/vagrant/results #{@worker.vm.results_folder}"
        logger.info "Done."
      end

      def prepare_script
        logger.info '==> Prepare script...'

        commands = []
        commands << 'mkdir results'
        commands << "curl -O -L #{FILE_STORE}/#{@container_sha1}"
        commands << "tar -xzf #{@container_sha1}"
        commands << 'mv archives container'
        commands << "rm #{@container_sha1}"

        commands << "curl -O -L #{PUBLISH_BUILD_LIST_SCRIPT_PATH}"
        file_name = 'avokhmin-publish-build-list-script-master.tar.gz'
        commands << "tar -xzf #{file_name}"
        folder_name = file_name.gsub /\.tar\.gz$/, ''
        commands << "mv #{folder_name} publish-build-list-script"
        commands << "rm -rf #{file_name}"

        commands.each{ |c| @worker.vm.execute_command(c) }
      end

    end
  end
end