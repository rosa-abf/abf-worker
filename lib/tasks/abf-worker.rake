$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'abf-worker'
require 'resque/tasks'

namespace :abf_worker do
  desc 'Add test data'
  task :test_data do
    script_path = '/home/avokhmin/workspace/warpc/test_script.sh'
    Resque.enqueue(AbfWorker::Worker, 15, 'rosa', 64, script_path)
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

  desc "Destroy VM's"
  task :destroy_vms do
    AbfWorker::Worker.clean true
  end

end