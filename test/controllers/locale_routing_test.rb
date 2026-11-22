require "test_helper"

class LocaleRoutingTest < ActionDispatch::IntegrationTest
  def root_with(language)
    get "/", headers: { "Accept-Language" => language }
  end

  test "root redirects to the language from Accept-Language" do
    root_with "ru-RU,ru;q=0.9,en;q=0.8"

    assert_redirected_to "/ru/games"
  end

  test "root picks the first supported language in the header" do
    root_with "de,fr;q=0.8,ru;q=0.5"

    assert_redirected_to "/ru/games"
  end

  test "root falls back to the default language for unknown languages" do
    root_with "de-DE,fr;q=0.8"

    assert_redirected_to "/en/games"
  end

  test "root falls back to the default language without a header" do
    get "/"

    assert_redirected_to "/en/games"
  end

  test "root ignores garbage and oversized headers" do
    [ "'; DROP TABLE users;--", ";;;,,,", "x" * 10_000, "../../etc/passwd" ].each do |header|
      root_with header

      assert_redirected_to "/en/games", header.first(20)
    end
  end

  test "root response varies by Accept-Language" do
    get "/"

    assert_includes response.headers["Vary"].to_s, "Accept-Language"
  end

  test "a language prefix alone redirects to the games list" do
    get "/ru"

    assert_redirected_to "/ru/games"
  end

  test "an unknown language prefix returns 404" do
    get "/xx/games"

    assert_response :not_found
  end

  test "a path without a language prefix returns 404" do
    get "/games"

    assert_response :not_found
  end

  test "links keep the language of the request" do
    get "/ru/games"

    assert_response :success
    assert_select "a[href=?]", "/ru/games"
    assert_select "a[href=?]", "/en/games", count: 0
  end

  test "health check works without a prefix" do
    get "/up"

    assert_response :success
  end
end
