require 'resque'
require 'airbrake'
require 'yaml'
require 'newrelic_rpm'


ROOT = File.dirname(__FILE__) + '/..'
env = ENV['RAILS_ENV'] || ENV['ENV'] || 'development'


require 'logger'
logger = Logger.new(STDOUT)
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{severity} #{datetime.strftime("%Y-%m-%d %H:%M:%S")}: #{msg}\n"
end
Resque.logger = logger
Resque.logger.level = Logger::INFO

# Resque.redis = YAML.load_file("#{ROOT}/config/resque.yml")[env]
resque_config = YAML.load_file("#{ROOT}/config/resque.yml")[env]
Resque.redis = Redis.new(host:        resque_config.gsub(/\:.*$/, ''),
                         port:        resque_config.gsub(/.*\:/, ''),
                         driver:      :hiredis,
                         timeout:     30)

APP_CONFIG = YAML.load_file("#{ROOT}/config/application.yml")[env]

Airbrake.configure do |config|
  config.api_key = APP_CONFIG['airbrake_api_key']
end

require 'abf-worker/base_worker'
require 'abf-worker/iso_worker'
require 'abf-worker/rpm_worker'
require 'abf-worker/publish_worker'