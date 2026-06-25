# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
Game.find_or_create_by!(
  name: "Reaction Time",
  description: "Test your reaction time with this simple game.",
  system_name: "reaction_time"
)

Game.find_or_create_by!(
  name: "Nback",
  description: "Test your working memory with this simple game.",
  system_name: "nback"
)

Game.find_or_create_by!(
  name: "Stroop Test",
  description: "Test your cognitive flexibility with this simple game.",
  system_name: "stroop_test"
)
