require "test_helper"

# Checks the theme definitions in the Tailwind source: every role is mapped to a
# variable, every theme defines every role, and stimulus colors keep their hue.
class ThemeCssTest < ActiveSupport::TestCase
  CSS = Rails.root.join("app/assets/tailwind/application.css").read
  ROLES = %w[surface surface-raised ink ink-muted line accent accent-ink danger success].freeze
  STIMULI = %w[stimulus-red stimulus-green stimulus-blue stimulus-yellow].freeze

  def theme_block(theme)
    CSS[/(?:^|[,\s])\[data-theme="#{theme}"\]\s*\{(.*?)\}/m, 1]
  end

  def theme_theme_block = CSS[/@theme inline\s*\{(.*?)\n\}/m, 1]

  test "every role is exposed to utilities through @theme inline" do
    block = theme_theme_block
    assert block, "@theme inline block is missing"

    (ROLES + STIMULI).each do |role|
      assert_includes block, "--color-#{role}: var(--#{role})", role
    end
  end

  test "every theme defines every role" do
    ApplicationHelper::THEMES.each do |theme|
      block = theme_block(theme)
      assert block, "no [data-theme=\"#{theme}\"] block"

      (ROLES + STIMULI).each do |role|
        assert_match(/--#{role}:\s*\S/, block, "#{theme} lacks --#{role}")
      end
    end
  end

  test "the light theme is also the default without JavaScript" do
    assert_match(/:root,\s*\[data-theme="light"\]/, CSS)
  end

  test "stimulus colors keep hue and chroma in every theme, only lightness changes" do
    STIMULI.each do |role|
      values = ApplicationHelper::THEMES.map do |theme|
        theme_block(theme)[/--#{role}:\s*oklch\(\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*\)/, 0] &&
          theme_block(theme).match(/--#{role}:\s*oklch\(\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*\)/).captures
      end

      assert(values.all?, "#{role} must be written as oklch(L C H) in every theme")
      hues = values.map { |_l, _c, h| h }.uniq
      chromas = values.map { |_l, c, _h| c }.uniq
      assert_equal 1, hues.size, "#{role} hue differs between themes: #{hues}"
      assert_equal 1, chromas.size, "#{role} chroma differs between themes: #{chromas}"
    end
  end

  test "each theme tells the browser its color scheme" do
    ApplicationHelper::THEMES.each do |theme|
      assert_match(/color-scheme:\s*#{theme}/, theme_block(theme), theme)
    end
  end
end
