require "test_helper"

class MarkdownHelperTest < ActionView::TestCase
  test "plain markdown becomes html" do
    html = render_markdown("## Title\n\nSome **bold** and *soft* text.\n\n- one\n- two")

    assert_includes html, "<h2>Title</h2>"
    assert_includes html, "<strong>bold</strong>"
    assert_includes html, "<em>soft</em>"
    assert_includes html, "<li>one</li>"
  end

  test "result is html safe" do
    assert render_markdown("text").html_safe?
  end

  test "script tag is removed" do
    html = render_markdown("Hello\n\n<script>alert(1)</script>\n\nworld")

    assert_no_match(/<script/i, html)
    assert_no_match(/alert\(1\)/, html)
  end

  test "javascript: link is neutralized" do
    [ "[x](javascript:alert(1))", "[x](JaVaScRiPt:alert(1))", "[x](data:text/html;base64,PHNjcmlwdD4=)",
      "<a href=\"javascript:alert(1)\">x</a>" ].each do |source|
      html = render_markdown(source)

      assert_no_match(/javascript:/i, html, source)
      assert_no_match(/data:/i, html, source)
    end
  end

  test "http and https links are kept" do
    html = render_markdown("[a](https://example.com/a) [b](http://example.com/b)")

    assert_includes html, 'href="https://example.com/a"'
    assert_includes html, 'href="http://example.com/b"'
  end

  test "raw html img onerror is dropped" do
    html = render_markdown("<img src=x onerror=alert(1)>\n\n![alt](https://example.com/a.png)")

    assert_no_match(/<img/i, html)
    assert_no_match(/onerror/i, html)
  end

  test "attributes other than href are removed" do
    html = render_markdown("<a href=\"https://example.com\" onclick=\"x()\" style=\"color:red\">x</a>")

    assert_no_match(/onclick|style/i, html)
  end

  test "raw html blocks are dropped" do
    html = render_markdown("<iframe src=\"https://example.com\"></iframe>\n\n<div>raw</div>")

    assert_no_match(/<iframe|<div/i, html)
  end

  test "tags outside the allow list are removed but their text stays" do
    html = render_markdown("# Big heading")

    assert_no_match(/<h1/i, html)
    assert_includes html, "Big heading"
  end

  test "headings carry no anchor links" do
    assert_no_match(/<a/i, render_markdown("## Title"))
  end

  test "links with schemes other than http and https lose their href" do
    [ "[x](mailto:a@b.c)", "[x](ftp://example.com/f)", "[x](tel:123)" ].each do |source|
      html = render_markdown(source)

      assert_no_match(/href/i, html, source)
      assert_includes html, "x", source
    end
  end

  test "blank input gives an empty string" do
    assert_equal "", render_markdown(nil)
    assert_equal "", render_markdown("")
  end
end
