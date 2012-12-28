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

  desc "Destroy ISO worker VM's on production"
  task :destroy_vms do
    ENV['ENV'] = 'production'
    AbfWorker::IsoWorker.clean_up
    AbfWorker::RpmWorker.clean_up
    AbfWorker::RpmWorkerDefault.clean_up
    AbfWorker::PublishBuildListContainerMdvWorker.clean_up
    AbfWorker::PublishBuildListContainerMdvWorkerDefault.clean_up
    AbfWorker::PublishBuildListContainerRhelWorker.clean_up
    AbfWorker::PublishBuildListContainerRhelWorkerDefault.clean_up
  end

end