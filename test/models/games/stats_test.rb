require "test_helper"

class Games::StatsTest < ActiveSupport::TestCase
  test "median of an odd number of values" do
    assert_equal 300.0, Games::Stats.median([ 500, 100, 300 ])
  end

  test "median of an even number of values is the mean of the middle two" do
    assert_equal 250.0, Games::Stats.median([ 400, 100, 200, 300 ])
  end

  test "median ignores nil values" do
    assert_equal 200.0, Games::Stats.median([ nil, 100, 300, nil ])
  end

  test "median of nothing is nil" do
    assert_nil Games::Stats.median([])
    assert_nil Games::Stats.median([ nil, nil ])
  end
end
