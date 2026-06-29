import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stimulus", "status", "buttonsContainer", "colorBtn", "startBtn", "correct", "errors"]
  static values = {
    gameId: Number,
    gameSessionId: Number,
    sequence: Array,
    stimulusDuration: Number
  }

  connect() {
    this.resetGame()
    console.log(this.stimulusDurationValue)
  }

  resetGame() {
    this.currentIndex = 0
    this.correctCount = 0
    this.errorCount = 0
    this.isGameActive = false
    this.hasAnswered = false
    this.currentColor = null    

    // this.updateStats()
  }

  start() {
    this.resetGame()
    this.isGameActive = true

    this.startBtnTarget.classList.add("hidden")

    this.buttonsContainerTarget.classList.remove("hidden")
    this.buttonsContainerTarget.disabled = false

    this.statusTarget.textContent = "Игра началась..."

    setTimeout(() => this.showNextStimulus(), 1000)
  }

  showNextStimulus() {
    if (!this.isGameActive || this.currentIndex >= this.sequenceValue.length) {
      this.finish()
      return
    }

    this.hasAnswered = false

    const current = this.sequenceValue[this.currentIndex]

    this.currentColor = current[1]
    this.stimulusTarget.textContent = current[0]
    this.stimulusTarget.style.color = this.getHexColor(this.currentColor)

    // symbols animation
    this.stimulusTarget.classList.remove("animate-pop")
    void this.stimulusTarget.offsetWidth // force reflow
    this.stimulusTarget.classList.add("animate-pop")

    this.enableButtons()
  
    setTimeout(() => {
      this.checkIfMissed();
      this.stimulusTarget.textContent = "?"
      this.stimulusTarget.classList.remove("scale-110", "ring-4", "ring-violet-400")
      
      this.currentIndex++
      this.showNextStimulus()
    }, this.stimulusDurationValue)
  }

  selectColor(event) {
    if (!this.isGameActive || this.hasAnswered) return
    
    const selectedColor = event.currentTarget.dataset.color

    this.hasAnswered = true

    if (this.currentColor != selectedColor) {
      this.errorCount++;
      this.flash("!bg-red-500");
    } else {
      this.correctCount++;
      this.flash("!bg-emerald-500");
    }

    this.updateStats()
    this.disableButtons()
  }
  
  checkIfMissed() {
    if (this.hasAnswered) return;

    this.errorCount++;
    this.flash("!bg-red-500");
  }

  updateStats() {
    this.correctTarget.textContent = this.correctCount
    this.errorsTarget.textContent = this.errorCount
  }
  
  finish() {
    this.isGameActive = false
    this.statusTarget.textContent = `Игра окончена! Правильно: ${this.correctCount} | Ошибки: ${this.errorCount}`
    this.saveResults()
  }

  disableButtons() {
    this.colorBtnTargets.forEach(btn => btn.disabled = true)
  }

  enableButtons() {
    this.colorBtnTargets.forEach(btn => btn.disabled = false)
  }

  flash(colorClass) {
    this.stimulusTarget.classList.add(colorClass)

    setTimeout(() => {
      this.stimulusTarget.classList.remove(colorClass)
    }, 300)
  }

  getHexColor(colorName) {
    const map = {
      red:    "#ef4444",
      green:  "#22c55e",
      blue:   "#3b82f6",
      yellow: "#eab308",
    }
    return map[colorName?.toLowerCase()] || "#ffffff"
  }

  async saveResults() {
    const payload = {
      game_id: this.gameIdValue,
      result: {
        correct: this.correctCount,
        errors: this.errorCount,
        total_trials: this.sequenceValue.length        
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
}
