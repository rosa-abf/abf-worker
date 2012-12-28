require 'abf-worker/publish_build_list_container_base_worker'

module AbfWorker
  class PublishBuildListContainerMdvWorker < PublishBuildListContainerBaseWorker
    @queue = :publish_build_list_container_mdv_worker
  end

  class PublishBuildListContainerMdvWorkerDefault < PublishBuildListContainerMdvWorker
    @queue = :publish_build_list_container_mdv_worker_default
  end
end