require 'helper'

class TestRpmWorker < Test::Unit::TestCase

  context 'RHEL package' do
    setup do
      stub_redis
      @options = {
        'id'                  => 1163945,
        'arch'                => 'x86_64',
        'time_living'         => 43200,
        'distrib_type'        => 'rhel',
        'git_project_address' => 'https://abf.rosalinux.ru/avokhmin/wordpress.git',
        'commit_hash'         => 'a62e9f02199b7703299d2855fc82fd2e0be8b8c7',
        'include_repos'       => {
          'rosa-server2012_base_release' => 'http://abf-downloads.rosalinux.ru/rosa-server2012/repository/x86_64/base/release',
          'rosa-server2012_base_updates' => 'http://abf-downloads.rosalinux.ru/rosa-server2012/repository/x86_64/base/updates'
        },
        'bplname' => 'rosa-server2012',
        'user'    => {'uname' => 'abf-worker', 'email' => 'abf-worker@test.com'}
      }
      Resque.push(
        'rpm_worker_default',
        'class' => 'AbfWorker::RpmWorkerDefault',
        'args'  => [@options]
      )
    end


    should 'adds an entry to the RpmWorkerDefault queue' do
      assert_equal 1, @redis_instance.llen('queue:rpm_worker_default')
    end

    should 'build package' do
      expect{ AbfWorker::RpmWorkerDefault.perform @options }.to_not raise_error
    end

  end


  context 'MDV package' do
    setup do
      stub_redis
      @options = {
        'id'                  => 1163944,
        'arch'                => 'x86_64',
        'time_living'         => 43200,
        'distrib_type'        => 'mdv',
        'git_project_address' => 'https://abf.rosalinux.ru/avokhmin/at.git',
        'commit_hash'         => '32956275cf49c50146dd506425889d331cdbc936',
        'include_repos'       => {
          'rosa-rosa2012lts_main_release' => 'http://abf-downloads.rosalinux.ru/rosa2012lts/repository/x86_64/main/release',
          'rosa-rosa2012lts_main_updates' => 'http://abf-downloads.rosalinux.ru/rosa2012lts/repository/x86_64/main/updates'
        },
        'bplname' => 'rosa2012lts',
        'user'    => {'uname' => 'abf-worker', 'email' => 'abf-worker@test.com'}
      }
      Resque.push(
        'rpm_worker_default',
        'class' => 'AbfWorker::RpmWorkerDefault',
        'args'  => [@options]
      )
    end


    should 'adds an entry to the RpmWorkerDefault queue' do
      assert_equal 1, @redis_instance.llen('queue:rpm_worker_default')
    end

    should 'build package' do
      expect{ AbfWorker::RpmWorkerDefault.perform @options }.to_not raise_error
    end

  end

end
