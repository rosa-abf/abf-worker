require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'test/unit'
require 'shoulda'
require 'rspec'
require 'rr'
require 'mock_redis'

class Test::Unit::TestCase

  def stub_redis
    @redis_instance = MockRedis.new
    stub(Redis).new { @redis_instance }
    stub(Resque).redis { @redis_instance }
  end

end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'abf-worker'
