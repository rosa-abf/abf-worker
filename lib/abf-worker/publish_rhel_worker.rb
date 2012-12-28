require 'abf-worker/publish_base_worker'

module AbfWorker
  class PublishRhelWorker < PublishBaseWorker
    @queue = :publish_rhel_worker
  end

  class PublishBuildListContainerRhelWorkerDefault < PublishRhelWorker
    @queue = :publish_rhel_worker_default
  end
end