# Here's an idea, let's not reload the entire dev environment for each asset request.  Let's only do that on regular
# content requests.
class RailsDevTweaks::GranularAutoload::Middleware

  # Don't cleanup before the very first request
  class << self
    attr_writer :processed_a_request
    def processed_a_request?
      @processed_a_request
    end
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env.dup)

    # reload, or no?
    if Rails.application.config.dev_tweaks.granular_autoload_config.should_reload?(request)
      # Confusingly, we flip the request prepare/cleanup life cycle around so that we're only cleaning up on those
      # requests that want to be reloaded

      # No-op if this is the first request.  The initializers take care of that one.
      if self.class.processed_a_request? && reload_dependencies?
        # ActionDispatch::Reloader.cleanup!
        # ActionDispatch::Reloader.prepare!
        ActionDispatch::Reloader.reload!
      end
      self.class.processed_a_request = true

    elsif Rails.application.config.dev_tweaks.log_autoload_notice
      Rails.logger.info 'RailsDevTweaks: Skipping ActionDispatch::Reloader hooks for this request.'
    end

    return @app.call(env)
  end

  private

  def reload_dependencies?
    application = Rails.application

    application.config.reload_classes_only_on_change != true || application.reloaders.map(&:updated?).any?
  end
end
