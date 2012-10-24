require 'vagrant'
module AbfWorker
  class Worker
    @queue = :worker

    def self.perform(os, arch, script_path)
      find_or_create_vagrant_file os, arch
      env = Vagrant::Environment.new({:vagrantfile_name => 'rosa_64'})

      #puts 'Start to run vagrant-init...'
      #env.cli 'init', "test#{build_id}"
      #puts 'Finished running vagrant-init'

      #env.
      #env.cli 'up', "rosa_64"
      puts 'Start to run vagrant-up...'
#      env.cli 'up', "lucid32_#{build_id}"
      puts 'Finished running vagrant-up'

      puts 'Start to run vagrant-halt...'
#      env.cli 'halt', "lucid32_#{build_id}"
      puts 'Finished running vagrant-halt'
    end

    def self.find_or_create_vagrant_file(os, arch)
      worker_id = Process.getpgid(Process.ppid())
      vm_name = "#{os}_#{arch}_#{worker_id}"
      vagrantfile_name = File.dirname(__FILE__).to_s
      vagrantfile_name << '/../../vagrantfiles/'
      vagrantfile_name << vm_name
      unless File.exist?(vagrantfile_name)
        begin
          file = File.open(vagrantfile_name, "w")
          str = "
            Vagrant::Config.run do |config|
              config.vm.define :#{vm_name} do |vm_config|
                vm_config.vm.box = '#{os}_#{arch}'
              end
            end"
          file.write(str) 
        rescue IOError => e
          #some error occur, dir not writable etc.
        ensure
          file.close unless file.nil?
        end
      end
    end

  end
end