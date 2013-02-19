$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'abf-worker'
require 'resque/tasks'

namespace :abf_worker do
  desc 'Init dev env'
  task :init_env do
    path = File.dirname(__FILE__).to_s + '/../../'
    Dir.mkdir path + 'log'
  end

  desc 'Init VM'
  task :init do
    vm_config = YAML.load_file(File.dirname(__FILE__).to_s + '/../../config/vm.yml')
    vm_config['virtual_machines'].each do |config|
      name, path = config['name'], config['path']
      puts 'Adding and initializing VM...'
      puts "- name: #{name}"
      puts "- path: #{path}"
      puts '-- adding VM...'
      system "vagrant box add #{name} #{path}"
      puts 'Done.'
    end
  end

  desc "Destroy worker VM's, logs and etc."
  task :clean_up do
    ps = %x[ ps aux | grep rosa | grep VBoxHeadless | grep -v grep | awk '{ print $2 }' ].
      split("\n").join(',')
    system "sudo kill -9 #{ps}" unless ps.empty?
    
    vms = %x[ VBoxManage list vms | awk '{ print $1 }' | sed -e 's/\"//g' ].split("\n")
    vms.each{ |vm_id| system "VBoxManage unregistervm #{vm_id} --delete" } unless vms.empty?

    system "rm -f logs/*.log"
    system "rm -rf #{APP_CONFIG['tmp_path']}"
  end

end