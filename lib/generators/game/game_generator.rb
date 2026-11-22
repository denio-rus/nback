# Usage: bin/rails g game <name> --category=<key>
#
# Creates the files of a new game: strategy, partial, Stimulus controller,
# strategy test and the English texts. Registration needs no edits: Games::Registry finds
# the strategy by its file name and `bin/rails db:seed` creates the Game row.
class GameGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  class_option :category, type: :string, required: true,
                          desc: "One of: #{Games::CATEGORIES.join(', ')}"

  NAME_FORMAT = /\A[a-z][a-z0-9_]*\z/

  def validate_arguments
    unless file_name.match?(NAME_FORMAT) && name == file_name
      raise Thor::Error, "Name must be snake_case (letters, digits, underscores), got #{name.inspect}"
    end
    return if Games::CATEGORIES.include?(options[:category])

    raise Thor::Error, "Unknown category #{options[:category].inspect}. Use one of: #{Games::CATEGORIES.join(', ')}"
  end

  def create_strategy
    template "strategy.rb.tt", "app/models/games/#{file_name}_strategy.rb"
  end

  def create_partial
    template "partial.html.erb.tt", "app/views/games/_#{file_name}.html.erb"
  end

  def create_controller
    template "controller.js.tt", "app/javascript/controllers/games/#{file_name}_controller.js"
  end

  def create_test
    template "strategy_test.rb.tt", "test/models/games/#{file_name}_strategy_test.rb"
  end

  # English is the source language; other languages are translations of this file.
  def create_locale
    template "locale.en.yml.tt", "config/locales/games/#{file_name}.en.yml"
  end

  private

  def category = options[:category]
  def stimulus_name = file_name.dasherize
end
