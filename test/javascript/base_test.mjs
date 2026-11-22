// Run with: node --test test/javascript/
// Plain Node test runner, no extra packages.
import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"

// The app has no package.json (importmap, no bundler), so Node would treat the
// .js file as CommonJS. Load its source as an ES module through a data URL.
const source = readFileSync(new URL("../../app/javascript/controllers/games/base.js", import.meta.url), "utf8")
const { t, formatNumber, createTimers, submitResult } =
  await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)

test("t returns the message for a key", () => {
  assert.equal(t({ start: "Start" }, "start"), "Start")
})

test("t substitutes %{name} placeholders", () => {
  assert.equal(t({ trial: "Trial %{n} of %{total}" }, "trial", { n: 3, total: 10 }), "Trial 3 of 10")
})

test("t supports nested keys with dots", () => {
  assert.equal(t({ colors: { red: "Red" } }, "colors.red"), "Red")
})

test("t returns the key itself when the message is missing", () => {
  assert.equal(t({}, "missing.key"), "missing.key")
})

test("t keeps an unknown placeholder visible instead of printing undefined", () => {
  assert.equal(t({ a: "Hi %{who}" }, "a", {}), "Hi %{who}")
})

test("t does not interpret html in messages or values", () => {
  assert.equal(t({ a: "<b>%{x}</b>" }, "a", { x: "<i>" }), "<b><i></b>")
})

test("formatNumber uses the lang of the document", () => {
  globalThis.document = { documentElement: { lang: "en" } }
  assert.equal(formatNumber(1234.5), "1,234.5")
  globalThis.document = { documentElement: { lang: "ru" } }
  assert.match(formatNumber(1234.5), /^1\s234,5$/)
})

test("createTimers.set runs a callback and clearAll cancels pending ones", async () => {
  const timers = createTimers()
  let fired = []
  timers.set(() => fired.push("a"), 5)
  timers.set(() => fired.push("b"), 5)
  timers.clearAll()
  await new Promise((resolve) => setTimeout(resolve, 30))
  assert.deepEqual(fired, [])
})

test("createTimers.clear cancels one timer only", async () => {
  const timers = createTimers()
  let fired = []
  const first = timers.set(() => fired.push("a"), 5)
  timers.set(() => fired.push("b"), 5)
  timers.clear(first)
  await new Promise((resolve) => setTimeout(resolve, 30))
  assert.deepEqual(fired, ["b"])
})

test("submitResult posts json with the csrf token to the given url", async () => {
  globalThis.document = { querySelector: () => ({ content: "token123" }) }
  let request
  globalThis.fetch = async (url, options) => {
    request = { url, options }
    return { ok: true, status: 200, json: async () => ({ id: 1 }) }
  }

  const response = await submitResult("/en/games/1/game_sessions/2/submit_result", { correct: 3 })

  assert.equal(request.url, "/en/games/1/game_sessions/2/submit_result")
  assert.equal(request.options.method, "POST")
  assert.equal(request.options.headers["X-CSRF-Token"], "token123")
  assert.equal(request.options.headers["Content-Type"], "application/json")
  assert.deepEqual(JSON.parse(request.options.body), { result: { correct: 3 } })
  assert.deepEqual(response, { ok: true, status: 200, body: { id: 1 } })
})

test("submitResult reports a failed request without throwing", async () => {
  globalThis.document = { querySelector: () => ({ content: "t" }) }
  globalThis.fetch = async () => ({ ok: false, status: 409, json: async () => ({ error: "already_submitted" }) })

  const response = await submitResult("/x", {})

  assert.equal(response.ok, false)
  assert.equal(response.status, 409)
  assert.equal(response.body.error, "already_submitted")
})

test("submitResult survives a network error", async () => {
  globalThis.document = { querySelector: () => ({ content: "t" }) }
  globalThis.fetch = async () => { throw new Error("offline") }

  const response = await submitResult("/x", {})

  assert.deepEqual(response, { ok: false, status: 0, body: null })
})
