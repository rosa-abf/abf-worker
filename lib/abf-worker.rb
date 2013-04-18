require 'resque'
require 'airbrake'
require 'yaml'


ROOT = File.dirname(__FILE__) + '/..'
env = ENV['RAILS_ENV'] || ENV['ENV'] || 'development'

resque_config = YAML.load_file("#{ROOT}/config/resque.yml")
Resque.redis = resque_config[env]

APP_CONFIG = YAML.load_file("#{ROOT}/config/application.yml")[env]

Airbrake.configure do |config|
  config.api_key = APP_CONFIG['airbrake_api_key']
end

require 'abf-worker/base_worker'
require 'abf-worker/iso_worker'
require 'abf-worker/rpm_worker'
require 'abf-worker/publish_worker'