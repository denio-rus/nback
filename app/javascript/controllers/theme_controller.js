import { Controller } from "@hotwired/stimulus"

// Switches the color theme. The choice is kept in localStorage, never on the
// server. The initial theme is set by the inline script in the layout head.
export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.markCurrent()
  }

  choose({ params: { name } }) {
    if (!this.allowedThemes().includes(name)) return

    document.documentElement.dataset.theme = name
    try { localStorage.setItem("theme", name) } catch (_error) { /* storage may be blocked */ }
    this.markCurrent()
  }

  markCurrent() {
    const current = document.documentElement.dataset.theme
    this.buttonTargets.forEach((button) => {
      button.setAttribute("aria-pressed", String(button.dataset.themeNameParam === current))
    })
  }

  allowedThemes() {
    return this.buttonTargets.map((button) => button.dataset.themeNameParam)
  }
}
