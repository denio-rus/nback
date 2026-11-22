# Splits the trials of one play-through into blocks for the breakdown page.
# With phases there is one block per phase. Without them, 10 or more trials
# become 5 consecutive blocks of nearly equal size, fewer trials give none.
module Games::Blocks
  BLOCK_COUNT = 5
  MIN_TRIALS = 10

  Block = Struct.new(:label, :count, :median_rt_ms, :error_rate, keyword_init: true)

  def self.call(trials, phases: [])
    trials = Array(trials)
    return by_phase(trials, phases) if phases.present?
    return [] if trials.size < MIN_TRIALS

    equal_parts(trials)
  end

  def self.by_phase(trials, phases)
    phases.map { |phase| build(phase, trials.select { |trial| trial["phase"] == phase }) }
  end

  # Block sizes differ by at most one: the first (size % 5) blocks get one extra trial.
  def self.equal_parts(trials)
    base, extra = trials.size.divmod(BLOCK_COUNT)
    from = 0

    Array.new(BLOCK_COUNT) do |index|
      size = base + (index < extra ? 1 : 0)
      part = trials[from, size]
      from += size
      build(index + 1, part)
    end
  end

  def self.build(label, trials)
    Block.new(label: label, count: trials.size, median_rt_ms: median_rt(trials), error_rate: error_rate(trials))
  end

  # Median response time of correct answers that have a numeric time.
  def self.median_rt(trials)
    times = trials.select { |trial| trial["correct"] == true && trial["rt_ms"].is_a?(Numeric) }
    Games::Stats.median(times.map { |trial| trial["rt_ms"] })
  end

  def self.error_rate(trials)
    return nil if trials.empty?

    trials.count { |trial| trial["correct"] == false }.fdiv(trials.size)
  end

  private_class_method :by_phase, :equal_parts, :build, :median_rt, :error_rate
end
