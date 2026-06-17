class Games::BaseStrategy
  def prepare_session_data
    raise NotImplementedError, "Subclasses must implement prepare_session_data"
  end

  def handle_result(result)
    data.deep_symbolize_keys! if data.is_a?(Hash)
    data
  end

  def validate_result = true
end
