require 'abf-worker/exceptions/script_error'
require 'digest/md5'
require 'forwardable'

module AbfWorker
  module Runners
    class Iso
      extend Forwardable

      RPM_BUILD_SCRIPT_PATH = 'https://abf.rosalinux.ru/avokhmin/rpm-build-script/archive/avokhmin-rpm-build-script-master.tar.gz'

      attr_accessor :script_runner,
                    :can_run

      def_delegators :@worker, :logger

      def initialize(worker, git_project_address, commit_hash, build_requires, include_repos_hash)
        @worker = worker
        @vm = @worker.vm.get_vm
        @git_project_address = git_project_address
        @commit_hash = commit_hash
        @build_requires = build_requires
        @include_repos_hash = include_repos_hash
        @can_run = true
      end

      def run_script
        @script_runner = Thread.new do
          if @vm.communicator.ready?
            prepare_script
            logger.info '==> Run script...'

            command = []
            command << 'cd rpm-build-script;'
            command << "GIT_PROJECT_ADDRESS=#{@git_project_address}"
            command << "COMMIT_HASH=#{@commit_hash}"
            command << "BUILD_REQUIRES=#{@build_requires}"
            # command << "INCLUDE_REPOS_HASH='#{@include_repos_hash}'"
            command << '/bin/bash build.sh'
            begin
              @vm.execute_command command.join(' ')
              logger.info '==>  Script done with exit_status = 0'
              @worker.status = AbfWorker::BaseWorker::BUILD_COMPLETED
            rescue AbfWorker::Exceptions::ScriptError => e
              logger.info "==>  Script done with exit_status != 0. Error message: #{e.message}"
              @worker.status = AbfWorker::BaseWorker::BUILD_FAILED
            end
            save_results
          end
        end
        @script_runner.join if @can_run
      end

      private

      def save_results
        # Download ISOs and etc.
        logger.info '==> Saving results....'
        ['tar -zcvf results/archives.tar.gz archives', 'rm -rf archives'].each do |command|
          @vm.execute_command command
        end

        logger.info "==> Downloading results...."
        port = @vm.config.ssh.port
        system "scp -r -o 'StrictHostKeyChecking no' -i keys/vagrant -P #{port} vagrant@127.0.0.1:/home/vagrant/results #{@vm.results_folder}"
        logger.info "Done."
      end

      def prepare_script
        logger.info '==> Prepare script...'

        commands = []
        commands << "curl -O -L #{RPM_BUILD_SCRIPT_PATH}"
        file_name = 'avokhmin-rpm-build-script-master.tar.gz'
        commands << "tar -xzf #{file_name}"
        folder_name = file_name.gsub /\.tar\.gz$/, ''

        commands << "mv #{folder_name}/* rpm-build-script/"
        commands << "rm -rf #{folder_name}"

        commands.each{ |c| @vm.execute_command(c) }
      end

    end
  end
end