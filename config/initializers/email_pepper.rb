# The pepper is the secret key of the HMAC that turns an email address into
# users.email_digest. Losing or changing it makes password reset by email and
# the "email is taken" check stop working, so keep it apart from database
# backups (see README.md).
pepper = ENV["EMAIL_PEPPER"].presence

if pepper.nil?
  # `assets:precompile` in the Docker build runs in production with a dummy
  # secret key base and no secrets; it never touches user emails.
  building_image = ENV["SECRET_KEY_BASE_DUMMY"].present?

  if Rails.env.production? && !building_image
    raise "EMAIL_PEPPER is not set. Generate one with `bin/rails secret` and put it in the environment."
  end

  pepper = "dev-pepper"
end

Rails.configuration.x.email_pepper = pepper.freeze
