require 'abf-worker/publish_base_worker'

module AbfWorker
  class PublishMdvWorker < PublishBaseWorker
    @queue = :publish_mdv_worker
  end

  class PublishMdvWorkerDefault < PublishMdvWorker
    @queue = :publish_mdv_worker_default
  end
end