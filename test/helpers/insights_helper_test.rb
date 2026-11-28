require "test_helper"

class InsightsHelperTest < ActionView::TestCase
  test "chart_scale spreads values over the size" do
    assert_equal [ 0.0, 50.0, 100.0 ], chart_scale([ 10, 20, 30 ], 100)
  end

  test "chart_scale keeps the order, also for unsorted values" do
    assert_equal [ 100.0, 0.0, 50.0 ], chart_scale([ 30, 10, 20 ], 100)
  end

  test "chart_scale handles an empty array" do
    assert_equal [], chart_scale([], 100)
  end

  test "chart_scale puts a single value in the middle" do
    assert_equal [ 50.0 ], chart_scale([ 42 ], 100)
  end

  test "chart_scale does not divide by zero for equal values" do
    assert_equal [ 50.0, 50.0, 50.0 ], chart_scale([ 7, 7, 7 ], 100)
  end

  test "chart_scale skips nil values" do
    assert_equal [ 0.0, nil, 100.0 ], chart_scale([ 1, nil, 3 ], 100)
  end

  test "chart_scale can flip the axis so that larger values go up" do
    assert_equal [ 100.0, 0.0 ], chart_scale([ 1, 2 ], 100, invert: true)
  end

  test "chart_scale with a padding keeps points off the edge" do
    assert_equal [ 10.0, 90.0 ], chart_scale([ 1, 2 ], 100, padding: 10)
  end
end
