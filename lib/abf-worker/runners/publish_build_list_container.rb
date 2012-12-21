require 'abf-worker/exceptions/script_error'
require 'abf-worker/models/repository'
require 'digest/md5'
require 'forwardable'

module AbfWorker
  module Runners
    class PublishBuildListContainer
      extend Forwardable

      attr_accessor :script_runner,
                    :can_run

      def_delegators :@worker, :logger

      def initialize(worker, options)
        @worker = worker
        @container_sha1 = options['container_sha1']
        @platform = options['platform']
        @repository = options['repository']
        @can_run = true
        @packages = options['packages']
        @cleanup = options['cleanup']
      end

      def run_script
        if @cleanup
          @script_runner = Thread.new{ run_cleanup_script }
        else
          @script_runner = Thread.new{ run_build_script }
        end
        @script_runner.join if @can_run
      end

      def rollback
        unless @cleanup
          @worker.vm.rollback_vm
          run_build_script true
        end
      end

      private

      def remove_old_packages
        share_folder = @worker.vm.share_folder
        rep = @platform['released'] ? 'updates' : 'release'
        @packages['sources'].each{ |s|
          system "rm -f #{share_folder}/SRPMS/#{@repository['name']}/#{rep}/#{s}"
        }
        @packages['binaries'].each{ |s|
          system "rm -f #{share_folder}/#{@worker.vm.arch}/#{@repository['name']}/#{rep}/#{s}"
        }
      end

      def run_cleanup_script
        remove_old_packages
        if @worker.vm.communicator.ready?
          download_main_script

          command = base_command_for_run
          command << 'rebuild.sh'
          begin
            @worker.vm.execute_command command.join(' ')
          rescue => e
          end
        end
      end

      def run_build_script(rollback_activity = false)
        remove_old_packages unless rollback_activity
        if @worker.vm.communicator.ready?
          prepare_script
          init_gpg_keys unless rollback_activity
          logger.info "==> Run #{rollback_activity ? 'rollback activity ' : ''}script..."

          command = base_command_for_run
          command << (rollback_activity ? 'rollback.sh' : 'build.sh')
          critical_error = false
          begin
            @worker.vm.execute_command command.join(' ')
            logger.info '==>  Script done with exit_status = 0'
            @worker.status = AbfWorker::BaseWorker::BUILD_COMPLETED unless rollback_activity
          rescue AbfWorker::Exceptions::ScriptError => e
            logger.info "==>  Script done with exit_status != 0. Error message: #{e.message}"
            @worker.status = AbfWorker::BaseWorker::BUILD_FAILED unless rollback_activity
          rescue => e
            @worker.print_error e
            @worker.status = AbfWorker::BaseWorker::BUILD_FAILED unless rollback_activity
            critical_error = true
          end
          # No logs on publishing build_list
          # save_results 
          rollback if critical_error && !rollback_activity
        end
      end

      def base_command_for_run
        command = []
        command << 'cd publish-build-list-script/;'
        command << "RELEASED=#{@platform['released']}"
        command << "REPOSITORY_NAME=#{@repository['name']}"
        command << "ARCH=#{@worker.vm.arch}"
        command << "TYPE=#{@worker.vm.os}"
        command << '/bin/bash'
        command
      end

      def prepare_script
        logger.info '==> Prepare script...'

        commands = []
        commands << 'mkdir results'
        commands << "curl -O -L #{APP_CONFIG['file_store']['url']}/#{@container_sha1}"
        commands << "tar -xzf #{@container_sha1}"
        commands << 'mv archives container'
        commands << "rm #{@container_sha1}"

        commands.each{ |c| @worker.vm.execute_command(c) }
        download_main_script
      end

      def download_main_script
        commands = []
        commands << "curl -O -L #{APP_CONFIG['scripts']['publish_build_list']}"
        file_name = 'avokhmin-publish-build-list-script-master.tar.gz'
        commands << "tar -xzf #{file_name}"
        folder_name = file_name.gsub /\.tar\.gz$/, ''
        commands << "mv #{folder_name} publish-build-list-script"
        commands << "rm -rf #{file_name}"

        commands.each{ |c| @worker.vm.execute_command(c) }
      end

      def init_gpg_keys
        repository = AbfWorker::Models::Repository.find_by_id(options['repository']['id'])
        return if repository.nil? || repository.key_pair.secret.empty?

        @worker.vm.execute_command 'mkdir -m 700 /home/vagrant/.gnupg'
        dir = Dir.mktmpdir
        begin
          port = @worker.vm.get_vm.config.ssh.port
          [:pubring, :secring].each do |key|
            open("#{dir}/#{key}.txt", "w") { |f|
              f.write repository.key_pair.send(key == :secring ? :secret : :public)
            }
            system "gpg --homedir #{dir} --dearmor < #{dir}/#{key}.txt > #{dir}/#{key}.gpg"
            system "scp -o 'StrictHostKeyChecking no' -i keys/vagrant -P #{port} #{dir}/#{key}.gpg vagrant@127.0.0.1:/home/vagrant/.gnupg/#{key}.gpg"
          end
        ensure
          # remove the directory.
          FileUtils.remove_entry_secure dir
        end
      end

    end
  end
end