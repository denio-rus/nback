require "test_helper"
require "yaml"

# Guards the translation files that machine translation tends to break:
# missing keys, renamed %{placeholders} and empty values. English is the source.
class I18nTest < ActiveSupport::TestCase
  LOCALE_DIR = Rails.root.join("config/locales")
  SOURCE = "en"
  PLACEHOLDER = /%\{(\w+)\}/

  # Flattens nested hashes to { "a.b.c" => "text" }.
  def self.flatten(hash, prefix = nil)
    hash.each_with_object({}) do |(key, value), result|
      path = [ prefix, key ].compact.join(".")
      if value.is_a?(Hash)
        result.merge!(flatten(value, path))
      else
        result[path] = value
      end
    end
  end

  # Merges every config/locales/**/*.<locale>.yml into one flat hash.
  def self.load_locale(locale)
    Dir[LOCALE_DIR.join("**/*.#{locale}.yml")].sort.each_with_object({}) do |file, result|
      data = YAML.safe_load_file(file)
      raise "#{file} must start with the #{locale}: key" unless data.is_a?(Hash) && data.keys == [ locale.to_s ]

      result.merge!(flatten(data[locale.to_s]))
    end
  end

  def self.placeholders(value) = value.to_s.scan(PLACEHOLDER).flatten.sort

  # Plural forms differ between languages (ru has few and many), so keys that
  # end in a plural suffix are compared by their base key.
  PLURAL_SUFFIX = /\.(zero|one|two|few|many|other)\z/
  def self.base_keys(flat) = flat.keys.map { |key| key.sub(PLURAL_SUFFIX, "") }.uniq

  def self.problems(source, target)
    problems = []
    missing = base_keys(source) - base_keys(target)
    extra = base_keys(target) - base_keys(source)
    problems << "missing keys: #{missing.join(', ')}" if missing.any?
    problems << "extra keys: #{extra.join(', ')}" if extra.any?

    target.each do |key, value|
      problems << "empty value: #{key}" if value.nil? || value.to_s.strip.empty?
      source_key = source.key?(key) ? key : key.sub(PLURAL_SUFFIX, ".other")
      next unless source.key?(source_key)

      source_names = placeholders(source[source_key])
      target_names = placeholders(value)
      # count is always available for plural forms, other variables must match.
      next if (source_names - [ "count" ]).sort == (target_names - [ "count" ]).sort

      problems << "placeholders differ in #{key}: #{source_names} vs #{target_names}"
    end
    problems
  end

  # --- the checker itself ---

  test "checker finds a renamed placeholder" do
    found = self.class.problems({ "a" => "Hi %{name}" }, { "a" => "Привет %{nombre}" })

    assert_match(/placeholders differ in a/, found.join)
  end

  test "checker finds missing, extra and empty values" do
    found = self.class.problems({ "a" => "A", "b" => "B" }, { "a" => " ", "c" => "C" })

    assert_match(/missing keys: b/, found.join)
    assert_match(/extra keys: c/, found.join)
    assert_match(/empty value: a/, found.join)
  end

  test "checker accepts different plural forms" do
    source = { "n.one" => "%{count} error", "n.other" => "%{count} errors" }
    target = { "n.one" => "%{count} ошибка", "n.few" => "%{count} ошибки", "n.many" => "%{count} ошибок", "n.other" => "%{count} ошибки" }

    assert_empty self.class.problems(source, target)
  end

  test "checker accepts a clean translation" do
    assert_empty self.class.problems({ "a" => "Hi %{n}" }, { "a" => "Привет %{n}" })
  end

  # --- the real files ---

  test "every language is registered and has locale files" do
    I18n.available_locales.each do |locale|
      assert_not_empty self.class.load_locale(locale), "#{locale} has no keys"
    end
  end

  test "every file name uses a known language" do
    known = I18n.available_locales.map(&:to_s)
    Dir[LOCALE_DIR.join("**/*.yml")].each do |file|
      assert_includes known, File.basename(file, ".yml").split(".").last, "#{file} has an unknown language suffix"
    end
  end

  (I18n.available_locales.map(&:to_s) - [ SOURCE ]).each do |locale|
    test "#{locale} matches the English keys and placeholders" do
      found = self.class.problems(self.class.load_locale(SOURCE), self.class.load_locale(locale))

      assert_empty found, "Fix #{locale} translations:\n#{found.join("\n")}"
    end
  end

  test "English has no empty values" do
    empty = self.class.load_locale(SOURCE).select { |_key, value| value.to_s.strip.empty? }.keys

    assert_empty empty
  end
end
