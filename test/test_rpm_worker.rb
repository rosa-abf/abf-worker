require 'helper'

class TestRpmWorker < Test::Unit::TestCase

  context 'build MDV package' do
    setup do
      stub_redis
      @options = {
        "id"=>1163945,
        "arch"=>"x86_64",
        "time_living"=>43200,
        "distrib_type"=>"rhel",
        "git_project_address"=>"https://abf.rosalinux.ru/avokhmin/wordpress.git",
        "commit_hash"=>"a62e9f02199b7703299d2855fc82fd2e0be8b8c7",
        "include_repos"=>{
          "rosa-server2012_base_release"=>"http://abf-downloads.rosalinux.ru/rosa-server2012/repository/x86_64/base/release",
          "rosa-server2012_base_updates"=>"http://abf-downloads.rosalinux.ru/rosa-server2012/repository/x86_64/base/updates"}, "bplname"=>"rosa-server2012", "user"=>{"uname"=>"avokhmin", "email"=>"avokhmin@gmail.com"
        }
      }
      Resque.push(
        'rpm_worker_default',
        'class' => 'AbfWorker::RpmWorkerDefault',
        'args' => [@options]
      )
    end


    should 'adds an entry to the RpmWorkerDefault queue' do
      assert_equal 1, @redis_instance.llen('queue:rpm_worker_default')
    end

    should 'up VM' do
      expect{ AbfWorker::RpmWorkerDefault.perform @options }.to_not raise_error 
    end

  end

end
