require 'abf-worker/publish_base_worker'

module AbfWorker
  class PublishRhelWorker < PublishBaseWorker
    @queue = :publish_rhel_worker
  end

  class PublishRhelWorkerDefault < PublishRhelWorker
    @queue = :publish_rhel_worker_default
  end
end