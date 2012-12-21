require 'abf-worker/models/base'

module AbfWorker
  module Models
    class Repository < AbfWorker::Models::Base

      # A transformer. All data from an API will be transformed to 
      # BaseStat instance.
      class KeyPairStat < APISmith::Smash
        property :public, :transformer => :to_s
        property :secret, :transformer => :to_s
      end # KeyPairStat

      class RepositoryStat < APISmith::Smash
        property :id,       :transformer => :to_i
        property :name,     :transformer => :to_s
        property :key_pair, :transformer => KeyPairStat
      end # RepositoryStat

      class BaseStat < APISmith::Smash
        property :repository, :transformer => RepositoryStat
      end # BaseStat



      # Finds repository by repository_id
      # Returns nil on 500, 404, timeout HTTP errors and when 
      # repository_id doesn't set
      def self.find_by_id(id)
        api = new(id.to_s)
        repository = api.get('/', :transform => BaseStat ).repository
        return repository
      rescue => e
        # We don't raise exception, because high classes don't rescue it.
        AbfWorker::BaseWorker.print_error(e)
        return nil
      end

      protected

      def initialize(id)
        @id = id
      end

      def endpoint
        "repositories/#{@id}/key_pair"
      end

    end
  end
end