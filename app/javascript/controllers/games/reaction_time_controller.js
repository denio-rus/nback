import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["circle", "status", "results", "startBtn"]
  static values = { 
    gameId: Number,
    gameSessionId: Number,
    intervals: Array 
  }

  connect() {
    this.currentTrial = 0
    this.results = []
    this.isWaiting = false
    this.startTime = null
    this.timeout = null

    this.boundKeyHandler = this.handleKeyDown.bind(this)
  }

  start() {
    this.startBtnTarget.disabled = true
    this.results = []
    this.currentTrial = 0
    this.resultsTarget.innerHTML = ""

    this.statusTarget.textContent = "Приготовьтесь..."

    setTimeout(() => {
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

    this.statusTarget.textContent = `Попытка ${this.currentTrial} / ${this.intervalsValue.length}`

    this.circleTarget.style.backgroundColor = "#374151"

    setTimeout(() => {
      this.circleTarget.style.backgroundColor = "#22c55e"  // ярко-зелёный
      this.startTime = performance.now()

      const interval = this.intervalsValue[this.currentTrial - 1] || 1500

      this.timeout = setTimeout(() => {
        this.handleMiss()
      }, interval)
    }, 300) // небольшая задержка, чтобы было видно смену
  }

  handleKeyDown(e) {
    if (e.code !== "Space" || !this.isWaiting) return
    e.preventDefault()

    clearTimeout(this.timeout)

    const reactionTime = Math.round(performance.now() - this.startTime)

    this.results.push(reactionTime)
    this.isWaiting = false
    this.circleTarget.style.backgroundColor = "#374151"

    this.addResult(reactionTime)

    setTimeout(() => this.runNextTrial(), 700)
  }

  handleMiss() {
    if (!this.isWaiting) return
    this.isWaiting = false
    this.circleTarget.style.backgroundColor = "#374151"
    this.results.push(null)
    this.addResult(null)

    setTimeout(() => this.runNextTrial(), 7000)
  }

  addResult(time) {
    const div = document.createElement("div")
    div.className = "py-2"
    if (time === null) {
      div.innerHTML = `<span class="text-red-500">Попытка ${this.currentTrial}: Пропущено</span>`
    } else {
      div.textContent = `Попытка ${this.currentTrial}: ${time} мс`
    }
    this.resultsTarget.appendChild(div)
  }

  finish() {
    this.statusTarget.textContent = "Тест завершён!"
    this.disconnectKeyboard()
    this.saveResults()
  }

  async saveResults() {
    const validResults = this.results.filter(r => r !== null)
    const mean = validResults.length 
      ? Math.round(validResults.reduce((a, b) => a + b, 0) / validResults.length) 
      : 0

    const payload = {
      game_id: this.gameIdValue,
      result: {
        trials: this.results.length,
        reactions: this.results,
        mean_rt: mean,
        min_rt: Math.min(...validResults),
        max_rt: Math.max(...validResults),
        false_starts: this.results.filter(r => r === null).length
      }
    }

    await fetch(`/games/${this.gameIdValue}/game_sessions/${this.gameSessionIdValue}/submit_result`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify(payload)
    })
  }

  connectKeyboard() {
    this.boundKeyHandler = this.handleKeyDown.bind(this)
    document.addEventListener("keydown", this.boundKeyHandler)
  }

  disconnectKeyboard() {
    document.removeEventListener("keydown", this.boundKeyHandler)
  }
}
