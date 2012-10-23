require 'vagrant'
module AbfWorker
  class Worker
    @queue = :worker

    def self.perform(build_id, script_path)
      env = Vagrant::Environment.new

      #puts 'Start to run vagrant-init...'
      #env.cli 'init', "test#{build_id}"
      #puts 'Finished running vagrant-init'

      puts 'Start to run vagrant-up...'
      env.cli 'up', "test#{build_id}"
      puts 'Finished running vagrant-up'
    end

  end
end