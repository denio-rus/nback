require "test_helper"

# Templates and game controllers may use only color roles (bg-surface, text-ink,
# text-stimulus-red, ...), never palette classes, hex or rgb()/hsl() values.
class ThemeLintTest < ActiveSupport::TestCase
  PALETTE = %w[
    slate gray zinc neutral stone red orange amber yellow lime green emerald teal
    cyan sky blue indigo violet purple fuchsia pink rose white black
  ].join("|")
  UTILITIES = %w[bg text border ring fill stroke from via to divide outline].join("|")

  PALETTE_CLASS = /(?<![\w-])!?(?:#{UTILITIES})-(?:#{PALETTE})(?:-\d+)?(?![\w-])/
  HEX_COLOR = /#[0-9a-fA-F]{3,8}\b/
  COLOR_FUNCTION = /\b(?:rgb|hsl)a?\(/

  FILES = (
    Dir[Rails.root.join("app/views/**/*.erb")] +
    Dir[Rails.root.join("app/javascript/controllers/**/*.js")]
  ).reject { |path| path.start_with?(Rails.root.join("app/views/pwa").to_s) }.sort.freeze

  def violations_in(text)
    text.each_line.with_index(1).flat_map do |line, number|
      [ PALETTE_CLASS, HEX_COLOR, COLOR_FUNCTION ].filter_map do |pattern|
        match = line[pattern]
        "line #{number}: #{match}" if match
      end
    end
  end

  test "palette classes are caught" do
    assert_not_empty violations_in('class="bg-blue-600"')
    assert_not_empty violations_in('class="hover:bg-blue-700"')
    assert_not_empty violations_in('class="!bg-red-500"')
    assert_not_empty violations_in('class="text-white"')
    assert_not_empty violations_in('class="from-indigo-600 to-violet-600"')
    assert_not_empty violations_in('classList.add("border-gray-200")')
  end

  test "color roles are allowed" do
    assert_empty violations_in('class="bg-surface text-ink border-line"')
    assert_empty violations_in('class="text-stimulus-red bg-accent text-accent-ink"')
    assert_empty violations_in('class="bg-danger text-success !bg-success"')
    assert_empty violations_in('class="bg-surface-raised text-ink-muted"')
  end

  test "hex and color functions are caught" do
    assert_not_empty violations_in("color: #fff;")
    assert_not_empty violations_in("fill: #22c55e")
    assert_not_empty violations_in("color: #AABBCCDD")
    assert_not_empty violations_in("color: rgb(0, 0, 0)")
    assert_not_empty violations_in("color: rgba(0, 0, 0, 0.5)")
    assert_not_empty violations_in("color: hsl(10 20% 30%)")
  end

  test "ordinary text is not mistaken for a color" do
    assert_empty violations_in('<a href="#main">Skip</a>')
    assert_empty violations_in("const redraw = items.length")
    assert_empty violations_in('class="text-sm px-2 py-1 rounded"')
    assert_empty violations_in("issue #1234567890")
  end

  test "pwa views are not linted" do
    assert FILES.none? { |path| path.include?("/app/views/pwa/") }
    assert_not_empty FILES, "no files were found to lint"
  end

  test "templates and controllers use only color roles" do
    problems = FILES.filter_map do |path|
      found = violations_in(File.read(path))
      "#{Pathname(path).relative_path_from(Rails.root)}: #{found.join(', ')}" if found.any?
    end

    assert_empty problems, "palette colors found:\n#{problems.join("\n")}"
  end
end
