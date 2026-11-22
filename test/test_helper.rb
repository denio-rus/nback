ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

# Every route lives under /:locale, so integration tests use English by default.
# Pass `locale:` explicitly to a path helper to test another language.
class ActionDispatch::IntegrationTest
  setup { default_url_options[:locale] = :en }
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # rate_limit counters live in the cache; do not let one test use up another one's attempts.
    setup { Rails.cache.clear }

    # Add more helper methods to be used by all tests here...
    def sign_in(user)
      post session_url, params: { nickname: user.nickname, password: "password" }
    end

    def sign_in_as_admin(user)
      user.grant(:admin)
      sign_in(user)
    end
  end
end
