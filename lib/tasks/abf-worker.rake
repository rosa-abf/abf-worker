$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'abf-worker'

namespace :abf_worker do
  desc "Run worker"
  task :run do
    AbfWorker::Worker.new.run
  end
end