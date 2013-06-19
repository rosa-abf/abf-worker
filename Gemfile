source "http://rubygems.org"

gem 'rake'
gem 'resque', '1.24.1'
gem 'redis', '3.0.4'
gem 'hiredis', '~> 0.4.5'
# gem 'vagrant', git: 'git://github.com/mitchellh/vagrant.git', tag: 'v1.2.2'
gem 'vagrant', git: 'git://github.com/warpc/vagrant.git', branch: 'abf-worker'
gem 'sahara', '0.0.13'
gem 'log4r', '1.1.10'
gem 'api_smith', '1.2.0'

gem 'newrelic_rpm'
group :production do
  gem 'airbrake', '~> 3.1.6'
end

group :development do
  # deploy
  gem 'capistrano', :require => false
  gem 'rvm-capistrano', :require => false
  gem 'cape', :require => false
  gem 'capistrano_colors', :require => false
end

group :test do
  gem 'rspec'
  gem 'shoulda'
  gem 'rr'
  gem 'mock_redis'
  gem 'rake'
end