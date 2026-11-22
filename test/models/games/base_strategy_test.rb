require "test_helper"

class BaseStrategyTest < ActiveSupport::TestCase
  # Minimal concrete strategy used only to exercise the shared contract.
  class FakeStrategy < Games::BaseStrategy
    def category = "executive"
    def spec_version = "fake@1"
    def setup_game = { "limit" => 3 }
    def permitted_result_keys = [ :score, { values: [] } ]
    def extra_trial_keys = [ :shown ]
    def primary_unit = "ms"
    def sample_payload(_setup) = { "score" => 1 }
    def validate_result(setup, payload) = payload["score"].to_i <= setup["limit"]
    def score(_setup, payload) = { doubled: payload["score"].to_i * 2 }
  end

  setup do
    @strategy = FakeStrategy.new
    @setup = @strategy.setup_game
  end

  def trial(overrides = {})
    { "rt_ms" => 250, "correct" => true, "phase" => 1 }.merge(overrides)
  end

  test "categories are the five agreed keys" do
    assert_equal %w[perception executive memory metacognition vigilance], Games::CATEGORIES
  end

  test "permit drops unknown keys" do
    result = @strategy.permit({ "score" => 1, "evil" => 2 })

    assert_equal({ "score" => 1 }, result)
  end

  test "permit keeps array of scalars declared with an empty array" do
    result = @strategy.permit({ "values" => [ 1, 2, nil ], "evil" => [ 1 ] })

    assert_equal({ "values" => [ 1, 2, nil ] }, result)
  end

  test "permit drops unknown trial keys" do
    result = @strategy.permit({ "trials" => [ trial("hack" => 1) ] })

    assert_equal [ trial ], result["trials"]
  end

  test "permit keeps extra_trial_keys" do
    result = @strategy.permit({ "trials" => [ trial("shown" => "A") ] })

    assert_equal "A", result["trials"].first["shown"]
  end

  test "permit accepts ActionController::Parameters and symbol keys" do
    params = ActionController::Parameters.new(score: 2, evil: 1)

    assert_equal({ "score" => 2 }, @strategy.permit(params))
    assert_equal({ "score" => 2 }, @strategy.permit({ score: 2 }))
  end

  test "permit returns empty hash for non-hash input" do
    [ nil, "text", 42, [ 1, 2 ] ].each do |input|
      assert_equal({}, @strategy.permit(input), "input: #{input.inspect}")
    end
  end

  test "handle_result raises InvalidResult when validate_result is false" do
    assert_raises(Games::BaseStrategy::InvalidResult) do
      @strategy.handle_result(@setup, { "score" => 99 })
    end
  end

  test "handle_result raises InvalidResult for more than 500 trials" do
    too_many = Array.new(501) { trial }

    assert_raises(Games::BaseStrategy::InvalidResult) do
      @strategy.handle_result(@setup, { "score" => 1, "trials" => too_many })
    end
  end

  test "handle_result accepts exactly 500 trials" do
    result = @strategy.handle_result(@setup, { "score" => 1, "trials" => Array.new(500) { trial } })

    assert_equal 500, result["trials"].size
  end

  test "handle_result merges score into permitted payload with string keys" do
    result = @strategy.handle_result(@setup, { "score" => 2, "evil" => 1 })

    assert_equal({ "score" => 2, "doubled" => 4 }, result)
  end

  test "system_name is derived from the class name" do
    assert_equal "fake", @strategy.system_name
    assert_equal "reaction_time", Games::ReactionTimeStrategy.new.system_name
  end

  test "defaults for optional parts of the contract" do
    base = Games::BaseStrategy.new

    assert_nil base.article_slug
    assert_equal [], base.extra_trial_keys
    assert_equal [], base.phases
    assert_nil base.primary_metric({})
    assert_nil base.secondary_metric({})
    assert_nil base.secondary_unit
    assert_equal({}, base.score({}, {}))
    assert base.validate_result({}, {})
  end

  test "base class requires the mandatory parts of the contract" do
    base = Games::BaseStrategy.new

    %i[category spec_version setup_game permitted_result_keys primary_unit].each do |name|
      assert_raises(NotImplementedError, "#{name} should be required") { base.public_send(name) }
    end
    assert_raises(NotImplementedError) { base.sample_payload({}) }
  end
end
