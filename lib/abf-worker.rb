require 'resque'
require 'airbrake'
require 'yaml'


ROOT = File.dirname(__FILE__) + '/..'
env = ENV['RAILS_ENV'] || ENV['ENV'] || 'development'

resque_config = YAML.load_file("#{ROOT}/config/resque.yml")[env]

Resque.redis = Redis.new(host:    resque_config.gsub(/\:.*$/, ''),
                         port:    resque_config.gsub(/.*\:/, ''),
                         timeout: 30,
                         driver:  :hiredis)

APP_CONFIG = YAML.load_file("#{ROOT}/config/application.yml")[env]

Airbrake.configure do |config|
  config.api_key = APP_CONFIG['airbrake_api_key']
end

Resque.before_first_fork do
  NewRelic::Agent.manual_start(dispatcher:              :resque,
                               sync_startup:            true,
                               start_channel_listener:  true,
                               report_instance_busy:    false)
end

Resque.before_fork do |job|
  NewRelic::Agent.register_report_channel(job.object_id)
end

Resque.after_fork do |job|
  NewRelic::Agent.after_fork(report_to_channel: job.object_id)
end

require 'abf-worker/base_worker'
require 'abf-worker/iso_worker'
require 'abf-worker/rpm_worker'
require 'abf-worker/publish_worker'