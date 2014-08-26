Active Job Basics
=================

This guide provides you with all you need to get started in creating,
enqueueing and executing background jobs.

After reading this guide, you will know:

* How to create jobs.
* How to enqueue jobs.
* How to run jobs in the background.
* How to send emails from your application async.

--------------------------------------------------------------------------------


Introduction
------------

Active Job is a framework for declaring jobs and making them run on a variety
of queueing backends. These jobs can be everything from regularly scheduled
clean-ups, to billing charges, to mailings. Anything that can be chopped up
into small units of work and run in parallel, really.


The Purpose of the Active Job
-----------------------------
The main point is to ensure that all Rails apps will have a job infrastructure
in place, even if it's in the form of an "immediate runner". We can then have
framework features and other gems build on top of that, without having to
worry about API differences between various job runners such as Delayed Job
and Resque. Picking your queuing backend becomes more of an operational concern,
then. And you'll be able to switch between them without having to rewrite your jobs.


Creating a Job
--------------

This section will provide a step-by-step guide to creating a job and enqueuing it.

### Create the Job

Active Job provides a Rails generator to create jobs. The following will create a
job in `app/jobs`:

```bash
$ bin/rails generate job guests_cleanup
create  app/jobs/guests_cleanup_job.rb
```

You can also create a job that will run on a specific queue:

```bash
$ bin/rails generate job guests_cleanup --queue urgent
create  app/jobs/guests_cleanup_job.rb
```

As you can see, you can generate jobs just like you use other generators with
Rails.

If you don't want to use a generator, you could create your own file inside of
`app/jobs`, just make sure that it inherits from `ActiveJob::Base`.

Here's what a job looks like:

```ruby
class GuestsCleanupJob < ActiveJob::Base
  queue_as :default

  def perform(*args)
    # Do something later
  end
end
```

### Enqueue the Job

Enqueue a job like so:

```ruby
MyJob.enqueue record  # Enqueue a job to be performed as soon the queueing system is free.
```

```ruby
MyJob.enqueue_at Date.tomorrow.noon, record  # Enqueue a job to be performed tomorrow at noon.
```

```ruby
MyJob.enqueue_in 1.week, record # Enqueue a job to be performed 1 week from now.
```

That's it!


Job Execution
-------------

If no adapter is set, the job is immediately executed.

### Backends

Active Job has adapters for the following queueing backends:

* [Backburner](https://github.com/nesquena/backburner)
* [Delayed Job](https://github.com/collectiveidea/delayed_job)
* [Qu](https://github.com/bkeepers/qu)
* [Que](https://github.com/chanks/que)
* [QueueClassic 2.x](https://github.com/ryandotsmith/queue_classic/tree/v2.2.3)
* [Resque 1.x](https://github.com/resque/resque/tree/1-x-stable)
* [Sidekiq](https://github.com/mperham/sidekiq)
* [Sneakers](https://github.com/jondot/sneakers)
* [Sucker Punch](https://github.com/brandonhilkert/sucker_punch)

#### Backends Features

|                       | Async | Queues  | Delayed | Priorities  | Timeout | Retries |
|-----------------------|-------|---------|---------|-------------|---------|---------|
| **Backburner**        | Yes   | Yes     | Yes     | Yes         | Job     | Global  |
| **Delayed Job**       | Yes   | Yes     | Yes     | Job         | Global  | Global  |
| **Que**               | Yes   | Yes     | Yes     | Job         | No      | Job     |
| **Queue Classic**     | Yes   | Yes     | Gem     | No          | No      | No      |
| **Resque**            | Yes   | Yes     | Gem     | Queue       | Global  | Yes     |
| **Sidekiq**           | Yes   | Yes     | Yes     | Queue       | No      | Job     |
| **Sneakers**          | Yes   | Yes     | No      | Queue       | Queue   | No      |
| **Sucker Punch**      | Yes   | Yes     | Yes     | No          | No      | No      |
| **Active Job Inline** | No    | Yes     | N/A     | N/A         | N/A     | N/A     |
| **Active Job**        | Yes   | Yes     | Yes     | No          | No      | No      |

### Change Backends

You can easily change your adapter:

```ruby
# be sure to have the adapter gem in your Gemfile and follow the adapter specific
# installation and deployment instructions
YourApp::Application.config.active_job.queue_adapter = :sidekiq
```


Queues
------

Most of the adapters support multiple queues. With Active Job you can schedule
the job to run on a specific queue:

```ruby
class GuestsCleanupJob < ActiveJob::Base
  queue_as :low_priority
  #....
end
```

Also you can prefix the queue name for all your jobs using
`config.active_job.queue_name_prefix` in `application.rb`:

```ruby
# config/application.rb
module YourApp
  class Application < Rails::Application
    config.active_job.queue_name_prefix = Rails.env
  end
end

# app/jobs/guests_cleanup.rb
class GuestsCleanupJob < ActiveJob::Base
  queue_as :low_priority
  #....
end

# Now your job will run on queue production_low_priority on your production
# environment and on beta_low_priority on your beta environment
```

NOTE: Make sure your queueing backend "listens" on your queue name. For some
backends you need to specify the queues to listen to.


Callbacks
---------

Active Job provides hooks during the lifecycle of a job. Callbacks allow you to
trigger logic during the lifecycle of a job.

### Available callbacks

* `before_enqueue`
* `around_enqueue`
* `after_enqueue`
* `before_perform`
* `around_perform`
* `after_perform`

### Usage

```ruby
class GuestsCleanupJob < ActiveJob::Base
  queue_as :default

  before_enqueue do |job|
    # do somthing with the job instance
  end

  around_perform do |job, block|
    # do something before perform
    block.call
    # do something after perform
  end

  def perform
    # Do something later
  end
end
```


ActionMailer
------------

One of the most common jobs in a modern web application is sending emails outside
of the request-response cycle, so the user doesn't have to wait on it. Active Job
is integrated with Action Mailer so you can easily send emails asynchronously:

```ruby
# If you want to send the email now use #deliver_now
UserMailer.welcome(@user).deliver_now

# If you want to send the email through Active Job use #deliver_later
UserMailer.welcome(@user).deliver_later
```


GlobalID
--------
Active Job supports GlobalID for parameters. This makes it possible to pass live
Active Record objects to your job instead of class/id pairs, which you then have
to manually deserialize. Before, jobs would look like this:

```ruby
class TrashableCleanupJob
  def perform(trashable_class, trashable_id, depth)
    trashable = trashable_class.constantize.find(trashable_id)
    trashable.cleanup(depth)
  end
end
```

Now you can simply do:

```ruby
class TrashableCleanupJob
  def perform(trashable, depth)
    trashable.cleanup(depth)
  end
end
```

This works with any class that mixes in `ActiveModel::GlobalIdentification`, which
by default has been mixed into Active Model classes.


Exceptions
----------

Active Job provides a way to catch exceptions raised during the execution of the
job:

```ruby

class GuestsCleanupJob < ActiveJob::Base
  queue_as :default

  rescue_from(ActiveRecord::RecordNotFound) do |exception|
   # do something with the exception
  end

  def perform
    # Do something later
  end
end
```
