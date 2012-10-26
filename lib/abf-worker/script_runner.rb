module AbfWorker
  module ScriptRunner

    def run_script
      puts 'Run scripts...'
      # TODO: run script
      commands = ['ls -l','ls -l /vagrant', 'touch /vagrant/from_vb.txt']

      communicator = @vagrant_env.vms[@vm_name.to_sym].communicate
      if communicator.ready?
        commands.each{ |c| communicator.execute c }
      end
    end

  end
end