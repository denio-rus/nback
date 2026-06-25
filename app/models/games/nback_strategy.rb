class Games::NbackStrategy < Games::BaseStrategy
  def setup_game
    { sequence: (1..20).map { rand(1..9) }, n: 2, stimulus_duration: 1500 }
  end

  def handle_result(result)
    result
  end

  def validate_result
    true
  end
end
