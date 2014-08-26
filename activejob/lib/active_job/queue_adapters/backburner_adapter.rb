require 'backburner'

module ActiveJob
  module QueueAdapters
    class BackburnerAdapter
      class << self
        def enqueue(job, *args)
          Backburner::Worker.enqueue JobWrapper, [ job.name, *args ], queue: job.queue_name
        end

        def enqueue_at(job, timestamp, *args)
          delay = Time.current.to_f - timestamp
          Backburner::Worker.enqueue JobWrapper, [ job.name, *args ], queue: job.queue_name, delay: delay
        end
      end

      class JobWrapper
        class << self
          def perform(job_name, *args)
            job_name.constantize.new.execute(*args)
          end
        end
      end
    end
  end
end
