$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'abf-worker'
require 'resque/tasks'
require 'vagrant'

namespace :abf_worker do
  desc 'Run worker'
  task :run do
    script_path = '/home/avokhmin/workspace/warpc/test_script.sh'
    build_id = 1
    Resque.enqueue(AbfWorker::Worker, build_id, script_path)
  end

end