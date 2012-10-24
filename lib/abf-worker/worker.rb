require 'vagrant'
module AbfWorker
  class Worker
    @queue = :worker

    def self.perform(os, arch, script_path)
      vm_name = "#{os}_#{arch}_#{get_worker_id}"
      find_or_create_vagrant_file vm_name, os, arch
      env = Vagrant::Environment.new(:vagrantfile_name => "vagrantfiles/#{vm_name}")

#      puts 'Enter sandbox mode'
#      env.cli 'sandbox', 'on', vm_name

      puts 'Start to run vagrant-up...'
      env.cli 'up', vm_name
      puts 'Finished running vagrant-up'

#      puts 'Rollback actions'
#      env.cli 'sandbox', 'rollback', vm_name

#      puts 'Exit sandbox mode'
#      env.cli 'sandbox', 'off', vm_name      

      puts 'Start to run vagrant-halt...'
      env.cli 'halt', vm_name
      puts 'Finished running vagrant-halt'
    rescue Resque::TermException
      clean
    end

    def self.find_or_create_vagrant_file(vm_name, os, arch)
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

    def self.clean
      files = []
      worker_id = get_worker_id
      path = Dir.pwd.to_s << '/vagrantfiles'
      Dir.new(path).entries.each do |n|
        if File.file?(path + "/#{n}") && n =~ /#{worker_id}/
          files << n
        end
      end
      puts files.inspect
      files.each do |f|
        env = Vagrant::Environment.new(:vagrantfile_name => "vagrantfiles/#{f}")
        puts 'Halt VM...'
        env.cli 'halt', '-f'
        puts 'Destroy VM...'
        env.cli 'destroy', '-f'

        File.delete(path + "/" + f)
      end
    end

    def self.get_worker_id
      Process.getpgid(Process.ppid())
    end

  end
end