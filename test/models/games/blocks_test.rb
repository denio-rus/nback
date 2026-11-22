require "test_helper"

class Games::BlocksTest < ActiveSupport::TestCase
  def trial(rt_ms: 300, correct: true, phase: nil)
    { "rt_ms" => rt_ms, "correct" => correct, "phase" => phase }
  end

  test "5 blocks for 100 trials" do
    blocks = Games::Blocks.call(Array.new(100) { trial })

    assert_equal 5, blocks.size
    assert_equal [ 20 ] * 5, blocks.map(&:count)
    assert_equal [ 1, 2, 3, 4, 5 ], blocks.map(&:label)
  end

  test "block sizes differ by at most one for 23 trials" do
    blocks = Games::Blocks.call(Array.new(23) { trial })

    assert_equal 5, blocks.size
    assert_equal 23, blocks.sum(&:count)
    assert_operator blocks.map(&:count).max - blocks.map(&:count).min, :<=, 1
  end

  test "blocks keep the order of trials" do
    trials = (1..10).map { |i| trial(rt_ms: i * 100) }
    blocks = Games::Blocks.call(trials)

    assert_equal [ 150.0, 350.0, 550.0, 750.0, 950.0 ], blocks.map(&:median_rt_ms)
  end

  test "empty for 9 trials" do
    assert_equal [], Games::Blocks.call(Array.new(9) { trial })
  end

  test "empty for no trials" do
    assert_equal [], Games::Blocks.call([])
    assert_equal [], Games::Blocks.call(nil)
  end

  test "phases produce one block per phase in order" do
    trials = [ trial(phase: 1), trial(phase: 1), trial(phase: 2), trial(phase: 3), trial(phase: 3), trial(phase: 3) ]
    blocks = Games::Blocks.call(trials, phases: [ 1, 2, 3 ])

    assert_equal [ 1, 2, 3 ], blocks.map(&:label)
    assert_equal [ 2, 1, 3 ], blocks.map(&:count)
  end

  test "phases work with fewer than 10 trials" do
    blocks = Games::Blocks.call([ trial(phase: 1), trial(phase: 2) ], phases: [ 1, 2 ])

    assert_equal 2, blocks.size
  end

  test "a phase without trials gives an empty block" do
    blocks = Games::Blocks.call([ trial(phase: 1) ], phases: [ 1, 2 ])

    assert_equal 0, blocks.last.count
    assert_nil blocks.last.median_rt_ms
    assert_nil blocks.last.error_rate
  end

  test "median ignores nil rt and wrong answers" do
    trials = [ trial(rt_ms: 100), trial(rt_ms: 300), trial(rt_ms: nil, correct: false),
               trial(rt_ms: 9000, correct: false), trial(rt_ms: nil) ]
    blocks = Games::Blocks.call(trials, phases: [ nil ])

    assert_equal 200.0, blocks.first.median_rt_ms
  end

  test "error_rate counts wrong answers including ones without rt" do
    trials = [ trial, trial, trial(rt_ms: nil, correct: false), trial(rt_ms: 500, correct: false) ]
    blocks = Games::Blocks.call(trials, phases: [ nil ])

    assert_equal 0.5, blocks.first.error_rate
  end

  test "all wrong gives nil median" do
    trials = Array.new(10) { trial(correct: false) }
    blocks = Games::Blocks.call(trials)

    assert(blocks.all? { |block| block.median_rt_ms.nil? })
    assert(blocks.all? { |block| block.error_rate == 1.0 })
  end
end
