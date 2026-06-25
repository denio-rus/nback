class Games::BaseStrategy
  def setup_game
    raise NotImplementedError, "Subclasses must implement setup_game"
  end

  def handle_result(result)
    data.deep_symbolize_keys! if data.is_a?(Hash)
    data
  end

  def validate_result = true
end
