require 'abf-worker/exceptions/script_error'

module AbfWorker
  module Runners
    module Iso
      RESULTS_FOLDER = File.dirname(__FILE__).to_s << '/../../../results'
      LOG_FOLDER = File.dirname(__FILE__).to_s << '/../../../log'

      def run_script
        communicator = @vagrant_env.vms[@vm_name.to_sym].communicate
        if communicator.ready?
          prepare_script communicator
          logger.info '==> Run script...'

          command = "cd iso_builder/; #{@params} ./#{@main_script}"
          exit_status = 0
          begin
            execute_command communicator, command, {:sudo => true}
            logger.info '==>  Script done with exit_status = 0'
          rescue AbfWorker::Exceptions::ScriptError => e
            logger.info "==>  Script done with exit_status != 0. Error message: #{e.message}"
          end

          save_results communicator
        end
      end

      def upload_results_to_file_store
        results_folder = RESULTS_FOLDER + "/build-#{@build_id}"
        if File.exists?(results_folder) && File.directory?(results_folder)
          Dir.new(results_folder).entries.each do |f|
            upload_file results_folder, f
          end
          Dir.rmdir results_folder
        end
        upload_file LOG_FOLDER, "abfworker::iso-worker-#{@build_id}.log"
      end

      private

      def upload_file(path, file_name)
        path_to_file = path + '/' + file_name
        return unless File.file?(path_to_file)
        logger.info "==> Uploading file '#{file_name}'...."

        # curl --user myuser@gmail.com:mypass -POST -F "file_store[file]=@files/archive.zip" http://file-store.rosalinux.ru/api/v1/file_stores.json
        command = 'curl --user '
        command << 'avokhmin@gmail.com:qwerty '
        command << '-POST -F "file_store[file]=@'
        command << path_to_file
        command << '" '
        # TODO: revert changes
        command << 'http://0.0.0.0:3001/api/v1/file_stores.json'
        # command << 'http://file-store.rosalinux.ru/api/v1/file_stores.json'
        system command

        File.delete path_to_file
        logger.info "Done."
      end

      def save_results(communicator)
        # Download ISOs and etc.
        logger.info '==> Saving results....'
        results_folder = RESULTS_FOLDER + "/build-#{@build_id}"
        Dir.rmdir results_folder if File.exists?(results_folder) && File.directory?(results_folder)
        Dir.mkdir results_folder

        ['tar -zcvf results/archives.tar.gz archives', 'rm -rf archives'].each do |command|
          execute_command communicator, command
        end

        files = ''
        communicator.execute 'ls -1 results/' do |channel, data|
          f = data.strip
          files << f unless f.empty?
        end
        files.split(/\b\s/).each do |file|
          file = file.strip
          next if file.empty?
          logger.info "==> Downloading file '#{file}'...."
          path = "/home/vagrant/results/" << file
          communicator.download path, (results_folder + '/' + file)
          logger.info "Done."
        end
      end

      def prepare_script(communicator)
        logger.info '==> Prepare script...'
        commands = []
        commands << 'mkdir results'
        commands << 'mkdir archives'
        commands << "curl -O #{@srcpath}"
        # TODO: revert changes when ABF will be working.
        file_name = @srcpath.match(/945501\/.*/)[0].gsub(/^945501\//, '')
        # file_name = @srcpath.match(/archive\/.*/)[0].gsub(/^archive\//, '')
        commands << "tar -xzf #{file_name}"
        folder_name = file_name.gsub /\.tar\.gz$/, ''
        commands << "mv #{folder_name} iso_builder"

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

    end
  end
end