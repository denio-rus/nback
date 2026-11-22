# Finds game strategies by their files, so adding a game needs no edits here.
# The file name is the trusted source: user input is only compared with the
# discovered names and never reaches constantize.
module Games::Registry
  STRATEGY_GLOB = Rails.root.join("app/models/games/*_strategy.rb")
  BASE_NAME = "base"

  # Sorted system names found on disk, e.g. ["nback", "reaction_time"].
  def self.system_names
    @system_names ||= Dir[STRATEGY_GLOB]
      .map { |path| File.basename(path, "_strategy.rb") }
      .reject { |name| name == BASE_NAME }
      .sort
      .freeze
  end

  def self.strategy_for(system_name)
    unless system_name.is_a?(String) && system_names.include?(system_name)
      raise ArgumentError, "unknown game: #{system_name.inspect}"
    end

    "Games::#{system_name.camelize}Strategy".constantize.new
  end

  # Creates or updates a Game row for every strategy. Never changes `active`
  # on existing rows; new rows start active.
  def self.sync!
    system_names.each do |system_name|
      strategy = strategy_for(system_name)
      game = Game.find_or_initialize_by(system_name: system_name)
      game.name = system_name.humanize
      game.description = "#{system_name.humanize} game" if game.description.blank?
      game.category = strategy.category
      game.active = true if game.new_record?
      game.save!
    end
  end
end
