import { Controller } from "@hotwired/stimulus"
import { t, createTimers, submitResult } from "controllers/games/base"

export default class extends Controller {
  static targets = ["circle", "status", "results", "startBtn"]
  static values = { 
    submitUrl: String,
    messages: Object,
    sequence: Array,
    stimulusDuration: Number
  }

  connect() {
    this.timers = createTimers()
    this.currentTrial = 0
    this.results = []
    this.isWaiting = false
    this.startTime = null
    this.timeout = null
  }

  disconnect() {
    this.timers.clearAll()
  }

  start() {
    this.startBtnTarget.disabled = true
    this.results = []
    this.currentTrial = 0
    this.resultsTarget.replaceChildren()

    this.statusTarget.textContent = this.message("get_ready")

    this.timers.set(() => {
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

    this.circleTarget.style.backgroundColor = "#374151"

    this.timers.set(() => {
      this.circleTarget.style.backgroundColor = "#22c55e"  // bright green
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
    this.circleTarget.style.backgroundColor = "#374151"

    this.addResult(reactionTime)

    this.timers.set(() => this.runNextTrial(), 700)
  }

  handleMiss() {
    if (!this.isWaiting) return
    this.isWaiting = false
    this.circleTarget.style.backgroundColor = "#374151"
    this.results.push(null)
    this.addResult(null)

    this.timers.set(() => this.runNextTrial(), 1000)
  }

  addResult(time) {
    const div = document.createElement("div")
    div.className = "py-2"
    if (time === null) {
      const missed = document.createElement("span")
      missed.className = "text-red-500"
      missed.textContent = this.message("trial_missed", { n: this.currentTrial })
      div.appendChild(missed)
    } else {
      div.textContent = this.message("trial_result", { n: this.currentTrial, time })
    }
    this.resultsTarget.appendChild(div)
  }

  finish() {
    this.statusTarget.textContent = this.message("finished")
    this.saveResults()
  }

  // Draft: the three-part game with two buttons replaces this in Task 6.5.
  async saveResults() {
    await submitResult(this.submitUrlValue, { reactions: this.results })
  }

  message(key, vars) {
    return t(this.messagesValue, key, vars)
  }
}
