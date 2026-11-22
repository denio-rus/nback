import { Controller } from "@hotwired/stimulus"
import { t, createTimers, submitResult } from "controllers/games/base"

export default class extends Controller {
  static targets = ["circle", "status", "results", "startBtn"]
  static values = {
    submitUrl: String,
    messages: Object,
    intervals: Array
  }

  connect() {
    this.timers = createTimers()
    this.currentTrial = 0
    this.results = []
    this.isWaiting = false
    this.startTime = null
    this.timeout = null

    this.boundKeyHandler = this.handleKeyDown.bind(this)
  }

  disconnect() {
    this.timers.clearAll()
    this.disconnectKeyboard()
  }

  start() {
    this.startBtnTarget.disabled = true
    this.results = []
    this.currentTrial = 0
    this.resultsTarget.innerHTML = ""

    this.statusTarget.textContent = this.message("get_ready")

    this.timers.set(() => {
      this.connectKeyboard()
      this.runNextTrial()
    }, 1000)
  }

  runNextTrial() {
    if (this.currentTrial >= this.intervalsValue.length) {
      this.finish()
      return
    }

    this.currentTrial++
    this.isWaiting = true

    this.statusTarget.textContent = this.message("trial", { current: this.currentTrial, total: this.intervalsValue.length })

    this.showCircleIdle()

    this.timers.set(() => {
      this.showCircleGo()
      this.startTime = performance.now()

      const interval = this.intervalsValue[this.currentTrial - 1] || 1500

      this.timeout = this.timers.set(() => {
        this.handleMiss()
      }, interval)
    }, 300) // short pause so the change of color is visible
  }

  handleKeyDown(e) {
    if (e.code !== "Space" || !this.isWaiting) return
    e.preventDefault()

    this.timers.clear(this.timeout)

    const reactionTime = Math.round(performance.now() - this.startTime)

    this.results.push(reactionTime)
    this.isWaiting = false
    this.showCircleIdle()

    this.addResult(reactionTime)

    this.timers.set(() => this.runNextTrial(), 700)
  }

  handleMiss() {
    if (!this.isWaiting) return
    this.isWaiting = false
    this.showCircleIdle()
    this.results.push(null)
    this.addResult(null)

    this.timers.set(() => this.runNextTrial(), 7000)
  }

  // The circle is grey while waiting and green when the player should react.
  showCircleIdle() {
    this.circleTarget.classList.remove("bg-success")
    this.circleTarget.classList.add("bg-ink-muted")
  }

  showCircleGo() {
    this.circleTarget.classList.remove("bg-ink-muted")
    this.circleTarget.classList.add("bg-success")
  }

  addResult(time) {
    const div = document.createElement("div")
    div.className = "py-2"
    if (time === null) {
      const missed = document.createElement("span")
      missed.className = "text-danger"
      missed.textContent = this.message("trial_missed", { n: this.currentTrial })
      div.appendChild(missed)
    } else {
      div.textContent = this.message("trial_result", { n: this.currentTrial, time })
    }
    this.resultsTarget.appendChild(div)
  }

  finish() {
    this.statusTarget.textContent = this.message("finished")
    this.disconnectKeyboard()
    this.saveResults()
  }

  // One trial per interval: the time in ms, or null for a missed trial. The
  // server recomputes "correct" and the counters, only the times are used.
  async saveResults() {
    const trials = this.results.map((rt) => ({ rt_ms: rt, correct: rt !== null, phase: null }))
    await submitResult(this.submitUrlValue, { trials })
  }

  connectKeyboard() {
    document.addEventListener("keydown", this.boundKeyHandler)
  }

  disconnectKeyboard() {
    document.removeEventListener("keydown", this.boundKeyHandler)
  }

  message(key, vars) {
    return t(this.messagesValue, key, vars)
  }
}
