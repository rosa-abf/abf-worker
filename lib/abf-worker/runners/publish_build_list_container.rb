require 'forwardable'
require 'abf-worker/models/repository'

module AbfWorker::Runners
  class PublishBuildListContainer
    extend Forwardable

    attr_accessor :script_runner,
                  :can_run

    def_delegators :@worker, :logger

    def initialize(worker, options)
      @worker       = worker
      @cmd_params       = options['cmd_params']
      @main_script      = options['main_script']
      @rollback_script  = options['rollback_script']
      @repository   = options['repository']
      @packages     = options['packages'] || {}
      @old_packages = options['old_packages'] || {}
      @can_run      = true
    end

    def run_script
      @script_runner = Thread.new{ run_build_script }
      @script_runner.join if @can_run
    end

    def rollback
      if @rollback_script
        @worker.vm.rollback_vm
        run_build_script true
      end
    end

    private

    def run_build_script(rollback_activity = false)
      if @worker.vm.communicator.ready?
        init_packages_lists
        @worker.vm.download_scripts
        init_gpg_keys unless rollback_activity
        logger.log "Run #{rollback_activity ? 'rollback activity ' : ''}script..."

        command = base_command_for_run
        command << (rollback_activity ? @rollback_script : @main_script)
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
      [
        'cd scripts/publish-packages/;',
        @cmd_params,
        '/bin/bash'
      ]
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
      return if packages.nil? || packages.empty?
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

    def init_gpg_keys
      repository = AbfWorker::Models::Repository.find_by_id(@repository['id']) if @repository
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