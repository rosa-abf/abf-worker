require 'abf-worker/exceptions/script_error'
require 'digest/md5'
require 'forwardable'

module AbfWorker
  module Runners
    class Iso
      extend Forwardable

      TWO_IN_THE_TWENTIETH = 2**20

      ROOT_PATH = File.dirname(__FILE__).to_s << '/../../../'
      LOG_FOLDER = ROOT_PATH + 'log'
      FILE_STORE = 'http://file-store.rosalinux.ru/api/v1/file_stores.json'
      FILE_STORE_CREATE_PATH = 'http://file-store.rosalinux.ru/api/v1/upload'
      FILE_STORE_CONFIG = ROOT_PATH + 'config/file-store.yml'

      attr_accessor :script_runner,
                    :can_run

      def_delegators :@worker, :logger

      def initialize(worker, srcpath, params, main_script)
        @worker = worker
        @srcpath = srcpath
        @params = params
        @main_script = main_script
        @can_run = true
      end

      def run_script
        @script_runner = Thread.new do
          if @worker.vm.communicator.ready?
            prepare_script
            logger.info '==> Run script...'

            command = "cd iso_builder/; #{@params} /bin/bash #{@main_script}"
            begin
              @worker.vm.execute_command command, {:sudo => true}
              logger.info '==>  Script done with exit_status = 0'
              @worker.status = AbfWorker::BaseWorker::BUILD_COMPLETED
            rescue AbfWorker::Exceptions::ScriptError => e
              logger.info "==>  Script done with exit_status != 0. Error message: #{e.message}"
              @worker.status = AbfWorker::BaseWorker::BUILD_FAILED
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
        logger.info '==> Saving results....'

        ['tar -zcvf results/archives.tar.gz archives', 'rm -rf archives'].each do |command|
          @worker.vm.execute_command command
        end

        logger.info "==> Downloading results...."
        port = @worker.vm.get_vm.config.ssh.port
        system "scp -r -o 'StrictHostKeyChecking no' -i keys/vagrant -P #{port} vagrant@127.0.0.1:/home/vagrant/results #{@worker.vm.results_folder}"
        # Umount tmpfs
        @worker.vm.execute_command 'umount /home/vagrant/iso_builder', {:sudo => true}
        logger.info "Done."
      end

      def prepare_script
        logger.info '==> Prepare script...'
        @worker.vm.execute_command 'mkdir /home/vagrant/iso_builder'
        # Create tmpfs
        @worker.vm.execute_command(
          'mount -t tmpfs tmpfs -o size=30000M,nr_inodes=10M  /home/vagrant/iso_builder',
          {:sudo => true}
        )

        commands = []
        commands << 'mkdir results'
        commands << 'mkdir archives'
        commands << "curl -O -L #{@srcpath}"
        # TODO: revert changes when ABF will be working.
        # file_name = @srcpath.match(/945501\/.*/)[0].gsub(/^945501\//, '')
        file_name = @srcpath.match(/archive\/.*/)[0].gsub(/^archive\//, '')
        commands << "tar -xzf #{file_name}"
        folder_name = file_name.gsub /\.tar\.gz$/, ''

        commands << "mv #{folder_name}/* iso_builder/"
        commands << "rm -rf #{folder_name}"

        commands.each{ |c| @worker.vm.execute_command(c) }
      end

    end
  end
end