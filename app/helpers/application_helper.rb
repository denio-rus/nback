module ApplicationHelper
  def game_color(game)
    colors = {
      1 => "bg-gradient-to-br from-blue-500 to-cyan-500",
      2 => "bg-gradient-to-br from-purple-500 to-violet-600",
      3 => "bg-gradient-to-br from-rose-500 to-pink-500",
      4 => "bg-gradient-to-br from-amber-500 to-orange-500",
      5 => "bg-gradient-to-br from-emerald-500 to-teal-500"
    }
    colors[rand(1..5)] ||"bg-gradient-to-br from-indigo-500 to-violet-600"
  end
end
