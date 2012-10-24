$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'abf-worker'
require 'resque/tasks'
require 'vagrant'

namespace :abf_worker do
  desc 'Add test data'
  task :test_data do
    script_path = '/home/avokhmin/workspace/warpc/test_script.sh'
    build_id = 1
    Resque.enqueue(AbfWorker::Worker, build_id, script_path)
  end

  desc 'Init VM'
  task :init do
    vm_config = YAML.load_file(File.dirname(__FILE__).to_s + '/../../config/vm.yml')
    env = Vagrant::Environment.new
    vm_config['virtual_machines'].each do |config|
      name, path = config['name'], config['path']
      puts 'Adding and initializing VM...'
      puts "- name: #{name}"
      puts "- path: #{path}"
      puts '-- adding VM...'
      env.cli 'box', 'add', name, path
      puts '-- creating VM...'
      env.cli 'up', name
      puts '-- halt VM...'
      env.cli 'halt', name
      puts 'Done.'
    end
  end

end