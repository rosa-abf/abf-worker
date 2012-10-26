module AbfWorker
  module ScriptRunner
    SCRIPTS_FOLDER = File.dirname(__FILE__).to_s << '/../../scripts'

    def run_script
      communicator = @vagrant_env.vms[@vm_name.to_sym].communicate
      if communicator.ready?
        prepare_script communicator
        puts 'Run scripts...'
        commands = [
          'ls -l',
          'ls -l /home/vagrant/script',
          '/home/vagrant/script/test_script.sh'
        ]
        commands.each do |c|
          communicator.execute c do |channel, data|
            if channel == :stdout
              puts "==== STDOUT:"
            else
              puts "==== STDERR:"
            end
            puts data 
          end
        end
      end
    end

    def prepare_script(communicator)
      puts 'Prepare script...'
      # Create folder for script
      communicator.execute 'mkdir /home/vagrant/script'
      #communicator.download(@script_path, '/home/vagrant/script')
      communicator.upload(@script_path, '/home/vagrant/script/test_script.sh')
      #communicator.download('/home/vagrant/postinstall.sh', '/home/avokhmin/workspace/warpc/abf-worker')
    end

  end
end