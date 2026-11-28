# Renders admin-written Markdown as safe HTML. Two layers: commonmarker drops
# raw HTML, then the output is cut down to an allow list of tags and
# attributes, and links are limited to http and https (or relative).
module MarkdownHelper
  MARKDOWN_TAGS = %w[p h2 h3 ul ol li strong em a blockquote code pre br].freeze
  MARKDOWN_ATTRIBUTES = %w[href].freeze
  MARKDOWN_SCHEMES = %w[http https].freeze

  def render_markdown(text)
    return "".html_safe if text.blank?

    html = Commonmarker.to_html(text.to_s, options: { render: { unsafe: false }, extension: { header_ids: nil } })
    clean = sanitize(html, tags: MARKDOWN_TAGS, attributes: MARKDOWN_ATTRIBUTES)
    restrict_link_schemes(clean).html_safe
  end

  private

  # Removes href values whose scheme is not on the list. Control characters
  # and spaces are ignored when looking for the scheme, as browsers do.
  def restrict_link_schemes(html)
    fragment = Nokogiri::HTML5.fragment(html)
    fragment.css("a[href]").each do |link|
      scheme = link["href"].gsub(/[[:cntrl:]\s]/, "")[/\A([a-z][a-z0-9+.\-]*):/i, 1]
      link.remove_attribute("href") if scheme && !MARKDOWN_SCHEMES.include?(scheme.downcase)
    end
    fragment.to_html
  end
end
