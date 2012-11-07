module AbfWorker
  module Runners
    module Iso
      BUILD_ISO_SCRIPT = File.dirname(__FILE__).to_s << '/../../../scripts/build_iso.sh'
      ISO_FOLDER = File.dirname(__FILE__).to_s << '/../../../iso'

      def run_script
        communicator = @vagrant_env.vms[@vm_name.to_sym].communicate
        if communicator.ready?
          prepare_script communicator
          logger.info '==> Run script...'

          command = "cd iso_builder/; #{@params} ./#{@main_script}"
          exit_status = execute_command(communicator, command, true)
          logger.info "==>  Script done with exit_status = #{exit_status}"

          save_results communicator
        end
      end

      private

      def save_results(communicator)
        # Download ISOs and etc.
        iso_folder = ISO_FOLDER << "/build-#{@build_id}"
        Dir.rmdir iso_folder
        Dir.mkdir iso_folder

        files = []
        communicator.execute 'ls -1 results/' do |channel, data|
          f = data.strip
          files << f unless f.empty?
        end
        files.each do |file|
          logger.info "==> Downloading file '#{file}'...."
          path = "/home/vagrant/results" << file
          communicator.download path, (iso_folder << file)
          logger.info "Done."
        end
      end

      def prepare_script(communicator)
        logger.info '==> Prepare script...'
        # Upload script from server into the VM
        # communicator.upload(BUILD_ISO_SCRIPT, '/home/vagrant/script.sh')
        commands = []
        commands << 'mkdir results'
        commands << "curl -O #{@srcpath}"
        file_name = @srcpath.match(/archive\/.*/)[0].gsub(/^archive\//, '')
        commands << "tar -xzf #{file_name}"
        commands << "mv #{file_name} iso_builder"

        commands.each{ |c| execute_command(communicator, c) }
      end

      def execute_command(communicator, command, sudo = false)
        logger.info "--> execute command with sudo = #{sudo}: #{command}"
        communicator.execute command, {:sudo => sudo} do |channel, data|
          logger.info data 
        end
      end

    end
  end
end