class Games::NbackStrategy < Games::BaseStrategy
  def prepare_session_data
    {}
  end

  def handle_result(result)
    result
  end

  def validate_result
    true
  end
end
