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

      attr_accessor :srcpath,
                    :params,
                    :main_script,
                    :script_runner,
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
          communicator = @worker.vm.get_vm.communicate
          if communicator.ready?
            prepare_script communicator
            logger.info '==> Run script...'

            command = "cd iso_builder/; #{@params} /bin/bash #{@main_script}"
            begin
              execute_command communicator, command, {:sudo => true}
              logger.info '==>  Script done with exit_status = 0'
              @worker.status = AbfWorker::BaseWorker::BUILD_COMPLETED
            rescue AbfWorker::Exceptions::ScriptError => e
              logger.info "==>  Script done with exit_status != 0. Error message: #{e.message}"
              @worker.status = AbfWorker::BaseWorker::BUILD_FAILED
            rescue => e
              logger.error e.message
              logger.error e.backtrace.join("\n")
              @worker.status = AbfWorker::BaseWorker::BUILD_FAILED
            end
            save_results communicator
          end
        end
        @script_runner.join if @can_run
      end

      def upload_results_to_file_store
        uploaded = []
        if File.exists?(results_folder) && File.directory?(results_folder)
          # Dir.new(results_folder).entries.each do |f|
          Dir[results_folder + '/**/'].each do |folder|
            Dir.new(folder).entries.each do |f|
              uploaded << upload_file(folder, f)
            end
          end
          system "rm -rf #{results_folder}"
        end
        uploaded << upload_file(LOG_FOLDER, "abfworker::iso-worker-#{@worker.build_id}.log")
        uploaded.compact
      end

      private

      def results_folder
        return @results_folder if @results_folder
        @results_folder = @worker.tmp_dir + '/results'
        Dir.mkdir(@results_folder) unless File.exists?(@results_folder)
        @results_folder << "/build-#{@build_id}"
        Dir.rmdir(@results_folder) if File.exists?(@results_folder)
        Dir.mkdir(@results_folder)
        @results_folder
      end

      def upload_file(path, file_name)
        path_to_file = path + '/' + file_name
        return unless File.file?(path_to_file)

        # Compress the log when file size more than 10MB
        file_size = (File.size(path_to_file).to_f / TWO_IN_THE_TWENTIETH).round(2)
        if path == LOG_FOLDER && file_size >= 10
          system "tar -zcvf #{path_to_file}.tar.gz #{path_to_file}"
          File.delete path_to_file
          path_to_file << '.tar.gz'
          file_name << '.tar.gz'
        end

        logger.info "==> Uploading file '#{file_name}'...."
        sha1 = Digest::SHA1.file(path_to_file).hexdigest

        # curl --user myuser@gmail.com:mypass -POST -F "file_store[file]=@files/archive.zip" http://file-store.rosalinux.ru/api/v1/file_stores.json
        if %x[ curl #{FILE_STORE}?hash=#{sha1} ] == '[]'
          command = 'curl --user '
          command << file_store_token
          command << ': -POST -F "file_store[file]=@'
          command << path_to_file
          command << '" '
          command << FILE_STORE_CREATE_PATH
          system command
        end

        File.delete path_to_file
        logger.info "Done."
        {:sha1 => sha1, :file_name => file_name, :size => file_size}
      end

      def save_results(communicator)
        # Download ISOs and etc.
        logger.info '==> Saving results....'

        ['tar -zcvf results/archives.tar.gz archives', 'rm -rf archives'].each do |command|
          execute_command communicator, command
        end

        logger.info "==> Downloading results...."
        port = @worker.vm.get_vm.config.ssh.port
        system "scp -r -o 'StrictHostKeyChecking no' -i keys/vagrant -P #{port} vagrant@127.0.0.1:/home/vagrant/results #{results_folder}"
        # Umount tmpfs
        execute_command communicator, 'umount /home/vagrant/iso_builder', {:sudo => true}
        logger.info "Done."
      end

      def prepare_script(communicator)
        logger.info '==> Prepare script...'
        execute_command(communicator, 'mkdir /home/vagrant/iso_builder')
        # Create tmpfs
        execute_command(
          communicator,
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

        commands.each{ |c| execute_command(communicator, c) }
      end

      def execute_command(communicator, command, opts = nil)
        opts = {
          :sudo => false,
          :error_class => AbfWorker::Exceptions::ScriptError
        }.merge(opts || {})
        logger.info "--> execute command with sudo = #{opts[:sudo]}: #{command}"
        communicator.execute command, opts do |channel, data|
          logger.info data 
        end
      end

      def file_store_token
        return @file_store_token if @file_store_token
        fs_config = YAML.load_file(FILE_STORE_CONFIG)
        @file_store_token = fs_config["server_#{@worker.server_id}"]
        @file_store_token
      end

    end
  end
end