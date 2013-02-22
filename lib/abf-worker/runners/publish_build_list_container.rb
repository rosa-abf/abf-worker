require 'forwardable'
require 'abf-worker/models/repository'

module AbfWorker
  module Runners
    class PublishBuildListContainer
      extend Forwardable

      attr_accessor :script_runner,
                    :type,
                    :can_run

      def_delegators :@worker, :logger

      def initialize(worker, options)
        @worker       = worker
        @cmd_params   = options['cmd_params']
        @repository   = options['repository']
        @packages     = options['packages'] || {}
        @old_packages = options['old_packages'] || {}
        @type         = options['type']
        @can_run      = true
      end

      def run_script
        if publish?
          @script_runner = Thread.new{ run_build_script }
        else
          @script_runner = Thread.new{ run_resign_script }
        end
        @script_runner.join if @can_run
      end

      def rollback
        if publish?
          @worker.vm.rollback_vm
          run_build_script true
        end
      end

      private

      def publish?
        @type == 'publish'
      end

      def run_resign_script
        if @worker.vm.communicator.ready?
          download_main_script
          init_gpg_keys

          command = base_command_for_run
          command << 'resign.sh'
          begin
            @worker.vm.execute_command command.join(' '), {:sudo => true}
          rescue => e
            @worker.print_error e
          end
        end
      end

      def run_build_script(rollback_activity = false)
        if @worker.vm.communicator.ready?
          init_packages_lists
          download_main_script
          init_gpg_keys unless rollback_activity
          logger.log "Run #{rollback_activity ? 'rollback activity ' : ''}script..."

          command = base_command_for_run
          command << (rollback_activity ? 'rollback.sh' : 'build.sh')
          critical_error = false
          begin
            @worker.vm.execute_command command.join(' '), {:sudo => true}
            logger.log 'Script done with exit_status = 0'
            @worker.status = AbfWorker::BaseWorker::BUILD_COMPLETED unless rollback_activity
          rescue AbfWorker::Exceptions::ScriptError => e
            logger.log "Script done with exit_status != 0. Error message: #{e.message}"
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
        command << @cmd_params
        command << '/bin/bash'
        command
      end

      def init_packages_lists
        logger.log 'Initialize lists of new and old packages...'
        @worker.vm.execute_command 'rm -rf container && mkdir container'

        [@packages, @old_packages].each_with_index do |packages, index|
          prefix = index == 0 ? 'new' : 'old'
          add_packages_to_list packages['sources'], "#{prefix}.SRPMS.list"
          (packages['binaries'] || {}).each do |arch, list|
            add_packages_to_list list, "#{prefix}.#{arch}.list"
          end
        end
      end

      def add_packages_to_list(packages = [], list_name)
        return if packages.empty?
        file = Tempfile.new("#{list_name}-#{@worker.build_id}", @worker.tmp_dir)
        begin
          packages.each{ |p| file.puts p }
          file.close
          @worker.vm.upload_file file.path, "/home/vagrant/container/#{list_name}"
        ensure
          file.close
          file.unlink
        end
      end

      def download_main_script
        commands = []
        treeish = APP_CONFIG['scripts']['publish_build_list']['treeish']
        commands << "rm -rf #{treeish}.tar.gz #{treeish} publish-build-list-script"
        commands << "curl -O -L #{APP_CONFIG['scripts']['publish_build_list']['path']}#{treeish}.tar.gz"

        file_name = "#{treeish}.tar.gz"
        commands << "tar -xzf #{file_name}"
        commands << "mv #{treeish} publish-build-list-script"
        commands << "rm -rf #{file_name}"

        commands.each{ |c| @worker.vm.execute_command(c) }
      end

      def init_gpg_keys
        repository = AbfWorker::Models::Repository.find_by_id(@repository['id'])
        return if repository.nil? || repository.key_pair.secret.empty?

        @worker.vm.execute_command 'mkdir -m 700 /home/vagrant/.gnupg'
        dir = Dir.mktmpdir('keys-', "#{@worker.tmp_dir}")
        begin
          [:pubring, :secring].each do |key|
            open("#{dir}/#{key}.txt", "w") { |f|
              f.write repository.key_pair.send(key == :secring ? :secret : :public)
            }
            system "gpg --homedir #{dir} --dearmor < #{dir}/#{key}.txt > #{dir}/#{key}.gpg"
            @worker.vm.upload_file "#{dir}/#{key}.gpg", "/home/vagrant/.gnupg/#{key}.gpg"
          end
        ensure
          # remove the directory.
          FileUtils.remove_entry_secure dir
        end
      end

    end
  end
end