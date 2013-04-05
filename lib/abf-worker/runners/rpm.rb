require 'forwardable'
require 'json'

module AbfWorker
  module Runners
    class Rpm
      extend Forwardable

      attr_accessor :script_runner,
                    :can_run,
                    :packages

      def_delegators :@worker, :logger

      def initialize(worker, options)
        @worker               = worker
        @git_project_address  = options['git_project_address']
        @commit_hash          = options['commit_hash']
        @build_requires       = options['build_requires']
        @include_repos        = options['include_repos']
        @bplname              = options['bplname']
        @user                 = options['user']
        @can_run              = true
        @packages             = []
      end

      def run_script
        @script_runner = Thread.new do
          if @worker.vm.communicator.ready?
            @worker.vm.download_scripts
            init_mock_configs
            logger.log 'Run script...'

            command = [
              'cd scripts/build-packages/;',
              "GIT_PROJECT_ADDRESS=#{@git_project_address}",
              "COMMIT_HASH=#{@commit_hash}",
              "ARCH=#{@worker.vm.arch}",
              "PLATFORM_NAME=#{@bplname}",
              "UNAME=#{@user['uname']}",
              "EMAIL=#{@user['email']}",
              '/bin/bash build.sh'
            ]
            # "BUILD_REQUIRES=#{@build_requires}"
            # "INCLUDE_REPOS='#{@include_repos}'"
            begin
              @worker.vm.execute_command command.join(' ')
              logger.log 'Script done with exit_status = 0'
              @worker.status = AbfWorker::BaseWorker::BUILD_COMPLETED
            rescue AbfWorker::Exceptions::ScriptError => e
              logger.log "Script done with exit_status != 0. Error message: #{e.message}"
              if e.message =~ /exit_status=>#{AbfWorker::BaseWorker::TESTS_FAILED}/ # 5
                @worker.status = AbfWorker::BaseWorker::TESTS_FAILED
              else
                @worker.status = AbfWorker::BaseWorker::BUILD_FAILED
              end
            rescue => e
              @worker.print_error e
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
        logger.log 'Saving results....'
        project_name = @git_project_address.
          scan(/\/([^\/]+)\.git/).inject.first

        logger.log "Downloading results...."
        @worker.vm.download_folder '/home/vagrant/results', @worker.vm.results_folder

        container_data = "#{@worker.vm.results_folder}/results/container_data.json"
        if File.exists?(container_data)
          @packages = JSON.parse(IO.read(container_data)).select{ |p| p['name'] }
          File.delete container_data
        end
        logger.log "Done."
      end

      def init_mock_configs
        @worker.vm.execute_command 'rm -rf container && mkdir container'
        file = Tempfile.new("media-#{@worker.build_id}.list", @worker.tmp_dir)
        begin
          @include_repos.each do |name, url|
            # Checks that repositoy exist
            if %x[ curl --write-out %{http_code} --silent --output /dev/null #{url} ] == '404'
              logger.log "Repository does not exist: #{url.gsub(/\:\/\/.*\:\@/, '://[FILTERED]@')}"
            else
              file.puts "#{name} #{url}"
            end
          end
          file.close
          @worker.vm.upload_file file.path, '/home/vagrant/container/media.list'
        ensure
          file.close
          file.unlink
        end
      end

    end
  end
end