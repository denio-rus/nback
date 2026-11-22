// Shared client helpers for game controllers. The file name has no
// "_controller" suffix, so Stimulus does not register it as a controller.
// It has no imports and no DOM access at load time, so it can be tested in Node.

// Looks up a message by key ("start" or "colors.red") in the messages object
// that the partial passes from I18n, and fills %{name} placeholders.
// A missing message returns the key, a missing variable keeps its placeholder.
export function t(messages, key, vars = {}) {
  const message = key.split(".").reduce((node, part) => (node == null ? undefined : node[part]), messages)
  if (typeof message !== "string") return key

  return message.replace(/%\{(\w+)\}/g, (placeholder, name) =>
    Object.prototype.hasOwnProperty.call(vars, name) ? String(vars[name]) : placeholder
  )
}

// Formats a number for the language of the page (<html lang>).
export function formatNumber(number) {
  return new Intl.NumberFormat(document.documentElement.lang || undefined).format(number)
}

// Timers that can be cancelled all at once, e.g. in disconnect().
export function createTimers() {
  const pending = new Set()

  return {
    set(callback, delay) {
      const id = setTimeout(() => {
        pending.delete(id)
        callback()
      }, delay)
      pending.add(id)
      return id
    },
    clear(id) {
      clearTimeout(id)
      pending.delete(id)
    },
    clearAll() {
      pending.forEach((id) => clearTimeout(id))
      pending.clear()
    }
  }
}

// Sends the result to the URL built by Rails (data-*-submit-url-value).
// Never throws: callers get { ok, status, body } and decide what to show.
export async function submitResult(url, result) {
  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({ result })
    })
    const body = await response.json().catch(() => null)
    return { ok: response.ok, status: response.status, body }
  } catch (_error) {
    return { ok: false, status: 0, body: null }
  }
}
