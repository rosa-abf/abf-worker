$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'abf-worker'
require 'resque/tasks'
require 'airbrake/tasks'

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

  desc "Safe destroy worker VM's"
  task :safe_clean_up do
    worker_ids = %x[ ps aux | grep resque | grep -v grep | awk '{ print $2 }' ].split("\n").join('|')

    %w(rpm iso publish).each do |worker|
      vagrantfiles = "#{APP_CONFIG['tmp_path']}/#{worker}/vagrantfiles"
      next unless File.exist?(vagrantfiles)
      Dir.new(vagrantfiles).entries.each do |vf_name|
        next if vf_name =~ /^\./ || vf_name =~ /\_(#{worker_ids})$/
        vagrant_env = Vagrant::Environment.new(cwd: vagrantfiles, vagrantfile_name: vf_name)
        vm_id = vagrant_env.vms[vf_name.to_sym].id

        ps = %x[ ps aux | grep VBox | grep #{vm_id} | grep -v grep | awk '{ print $2 }' ].split("\n").join(' ')
        system "sudo kill -9 #{ps}" unless ps.empty?
        system "VBoxManage unregistervm #{vm_id} --delete"
        FileUtils.rm_f "#{vagrantfiles}/#{vf_name}"
      end
    end
  end

  desc "Destroy worker VM's, logs and etc."
  task :clean_up do
    ps = %x[ ps aux | grep VBox | grep -v grep | awk '{ print $2 }' ].
      split("\n").join(' ')
    system "sudo kill -9 #{ps}" unless ps.empty?
    
    vms = %x[ VBoxManage list vms | awk '{ print $1 }' | sed -e 's/\"//g' ].split("\n")
    vms.each{ |vm_id| system "VBoxManage unregistervm #{vm_id} --delete" } unless vms.empty?

    system "rm -f logs/*.log"
    system "rm -rf #{APP_CONFIG['tmp_path']}"
  end

end