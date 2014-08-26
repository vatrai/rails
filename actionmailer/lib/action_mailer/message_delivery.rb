require 'delegate'

module ActionMailer

  # The <tt>ActionMailer::MessageDelivery</tt> class is used by
  # <tt>ActionMailer::Base</tt> when creating a new mailer.
  # <tt>MessageDelivery</tt> is a wrapper (+Delegator+ subclass) around a lazy
  # created <tt>Mail::Message</tt>. You can get direct access to the
  # <tt>Mail::Message</tt>, deliver the email or schedule the email to be sent
  # through Active Job.
  #
  #   Notifier.welcome(User.first)               # an ActionMailer::MessageDelivery object
  #   Notifier.welcome(User.first).deliver_now   # sends the email
  #   Notifier.welcome(User.first).deliver_later # enqueue email delivery as a job through Active Job
  #   Notifier.welcome(User.first).message       # a Mail::Message object
  class MessageDelivery < Delegator
    def initialize(mailer, mail_method, *args) #:nodoc:
      @mailer = mailer
      @mail_method = mail_method
      @args = args
    end

    def __getobj__ #:nodoc:
      @obj ||= @mailer.send(:new, @mail_method, *@args).message
    end

    def __setobj__(obj) #:nodoc:
      @obj = obj
    end

    # Returns the Mail::Message object
    def message
      __getobj__
    end

    # Enqueues the email to be delivered through Active Job. When the
    # job runs it will send the email using +deliver_now!+. That means
    # that the message will be sent bypassing checking +perform_deliveries+
    # and +raise_delivery_errors+, so use with caution.
    #
    #   Notifier.welcome(User.first).deliver_later
    #   Notifier.welcome(User.first).deliver_later(in: 1.hour)
    #   Notifier.welcome(User.first).deliver_later(at: 10.hours.from_now)
    #
    # Options:
    #
    # * <tt>:in</tt> - Enqueue the email to be delivered with a delay
    # * <tt>:at</tt> - Enqueue the email to be delivered at (after) a specific date / time
    def deliver_later!(options={})
      enqueue_delivery :deliver_now!, options
    end

    # Enqueues the email to be delivered through Active Job. When the
    # job runs it will send the email using +deliver_now+.
    #
    #   Notifier.welcome(User.first).deliver_later
    #   Notifier.welcome(User.first).deliver_later(in: 1.hour)
    #   Notifier.welcome(User.first).deliver_later(at: 10.hours.from_now)
    #
    # Options:
    #
    # * <tt>:in</tt> - Enqueue the email to be delivered with a delay
    # * <tt>:at</tt> - Enqueue the email to be delivered at (after) a specific date / time
    def deliver_later(options={})
      enqueue_delivery :deliver_now, options
    end

    # Delivers an email without checking +perform_deliveries+ and +raise_delivery_errors+,
    # so use with caution.
    #
    #   Notifier.welcome(User.first).deliver_now!
    #
    def deliver_now!
      message.deliver!
    end

    # Delivers an email:
    #
    #   Notifier.welcome(User.first).deliver_now
    #
    def deliver_now
      message.deliver
    end

    def deliver! #:nodoc:
      ActiveSupport::Deprecation.warn "#deliver! is deprecated and will be removed in Rails 5. " \
        "Use #deliver_now! to deliver immediately or #deliver_later! to deliver through Active Job."
      deliver_now!
    end

    def deliver #:nodoc:
      ActiveSupport::Deprecation.warn "#deliver is deprecated and will be removed in Rails 5. " \
        "Use #deliver_now to deliver immediately or #deliver_later to deliver through Active Job."
      deliver_now
    end

    private

      def enqueue_delivery(delivery_method, options={})
        args = @mailer.name, @mail_method.to_s, delivery_method.to_s, *@args
        enqueue_method = :enqueue
        if options[:at]
          enqueue_method = :enqueue_at
          args.unshift options[:at]
        elsif options[:in]
          enqueue_method = :enqueue_in
          args.unshift options[:in]
        end
        ActionMailer::DeliveryJob.send enqueue_method, *args
      end
  end
end
