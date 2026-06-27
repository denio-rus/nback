# 50 stimulus, 4 colors, 4 words, 1500ms duration
# colors: red, green, blue, yellow

class Games::StroopTestStrategy < Games::BaseStrategy
  def setup_game
    { sequence: make_combinations(50), stimulus_duration: 1500 }
  end

  def handle_result(result)
    # Implement result handling logic here
  end

  private
  def make_combinations(count)
    colors = sequence_generator(count)
    words = sequence_generator(count)

    words.map.with_index { [_1, colors[_2]] }
  end
  
  def sequence_generator(count)
    (1..count).map { [:red, :green, :blue, :yellow].sample }
  end
end
