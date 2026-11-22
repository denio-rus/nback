# Contract every game strategy follows. A new game is a subclass that fills in
# the metadata and hooks below; the shared flow in #handle_result stays as is.
class Games::BaseStrategy
  class InvalidResult < StandardError; end

  MAX_TRIALS = 500
  BASE_TRIAL_KEYS = %i[rt_ms correct phase].freeze
  # Version of the stored result layout (result["trials"] with BASE_TRIAL_KEYS).
  FORMAT = 1

  # --- Required metadata and hooks (subclasses must implement) ---

  # Key from Games::CATEGORIES.
  def category = not_implemented(:category)

  # Rules version in the form "<system_name>@<n>".
  def spec_version = not_implemented(:spec_version)

  # Material for one play-through (sequence, intervals, parameters).
  def setup_game = not_implemented(:setup_game)

  # Whitelist of client result keys. Symbols are scalar keys, a hash entry
  # such as { values: [] } declares an array of scalars.
  def permitted_result_keys = not_implemented(:permitted_result_keys)

  # Unit of the primary metric: "ms", "%" or "count".
  def primary_unit = not_implemented(:primary_unit)

  # A valid client result, used by the shared contract test.
  def sample_payload(_setup) = not_implemented(:sample_payload)

  # --- Optional parts with defaults ---

  # Slug of an article describing the test, if any.
  def article_slug = nil

  # Game-specific keys allowed inside each trial, besides BASE_TRIAL_KEYS.
  def extra_trial_keys = []

  # Ordered list of game parts (rules or levels); empty when there are none.
  def phases = []

  def validate_result(_setup, _payload) = true

  # Server-side recount of deterministic metrics; merged into the result.
  def score(_setup, _payload) = {}

  # The only reader of result["trials"], so the layout can change in one place.
  # Returns the trials as an array of hashes, or [] when there are none.
  def trials(result)
    list = result.is_a?(Hash) ? result["trials"] : nil
    list.is_a?(Array) ? list.grep(Hash) : []
  end

  # Two parts [from, to] whose medians are compared on the breakdown page
  # (the cost of switching the rule), or nil when the game has no such pair.
  def switch_cost_phases = nil

  # How one trial shows on the strip: :correct, :wrong (answered, but not right)
  # or :miss (no answer). The default reads the base keys; a game whose trials
  # carry no time overrides it.
  def trial_outcome(trial)
    return :correct if trial["correct"] == true

    trial["rt_ms"].nil? ? :miss : :wrong
  end

  def primary_metric(_result) = nil

  def secondary_metric(_result) = nil

  def secondary_unit = nil

  def system_name
    self.class.name.demodulize.delete_suffix("Strategy").underscore
  end

  # Reduces raw client input to whitelisted keys. Returns a Hash with string keys.
  def permit(raw)
    params = to_parameters(raw)
    return {} if params.nil?

    scalar_keys, array_keys = split_result_keys
    params.permit(*scalar_keys, array_keys.merge(trials: trial_keys)).to_h.to_hash
  end

  # Template method: permit, check limits, validate, then add server-side score.
  def handle_result(setup, raw)
    payload = permit(raw)

    if payload["trials"].is_a?(Array) && payload["trials"].size > MAX_TRIALS
      raise InvalidResult, "too many trials"
    end
    raise InvalidResult, "invalid result" unless validate_result(setup, payload)

    payload.merge(score(setup, payload).deep_stringify_keys).merge("format" => FORMAT)
  end

  private

  def not_implemented(name)
    raise NotImplementedError, "#{self.class.name} must implement ##{name}"
  end

  def trial_keys = BASE_TRIAL_KEYS + extra_trial_keys

  def to_parameters(raw)
    case raw
    when ActionController::Parameters then raw
    when Hash then ActionController::Parameters.new(raw)
    end
  end

  def split_result_keys
    entries = permitted_result_keys
    [ entries.grep(Symbol), entries.grep(Hash).reduce({}, :merge) ]
  end
end
