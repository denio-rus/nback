# Explicit namespace file for Games::*. Zeitwerk autoloads it together with
# the app/models/games/ directory.
module Games
  # Category keys for grouping games. Titles live in I18n (games.categories.<key>).
  CATEGORIES = %w[perception executive memory metacognition vigilance].freeze
end
