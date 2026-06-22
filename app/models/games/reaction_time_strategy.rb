class Games::ReactionTimeStrategy < Games::BaseStrategy
  def setup_game = {
    intervals: generate_intervals,
    locales: add_games_locales
  }

  def handle_result(result) = result

  def validate_result = true

  private

  def generate_intervals
    Array.new(10) { rand(1000...4000) }
  end

  def add_games_locales
    I18n.t("games.reaction_time")
  end
end
