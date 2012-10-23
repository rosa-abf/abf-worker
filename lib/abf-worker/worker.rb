module AbfWorker
  class Worker
    @queue = :worker

    def self.perform(box_path, script_path)
      puts "Hello world"
      puts box_path
      puts script_path
    end

  end
end