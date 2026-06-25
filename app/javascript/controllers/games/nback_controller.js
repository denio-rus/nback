import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stimulus", "status", "startBtn", "matchBtn", "correct", "errors"]
  static values = {
    gameId: Number,
    gameSessionId: Number,
    n: Number,           // уровень сложности (N=2, N=3 и т.д.)
    sequence: Array      // последовательность стимулов
  }

  connect() {
    console.log("✅ NBack controller connected")
    this.resetGame()
  }

  resetGame() {
    this.currentIndex = 0
    this.correctCount = 0
    this.errorCount = 0
    this.isGameActive = false
    this.hasAnswered = false
    this.expectedMatch = false
    this.nBackIdx = - this.nValue
    this.updateStats()
  }

  start() {
    this.resetGame()
    this.isGameActive = true
    this.startBtnTarget.disabled = true
    this.matchBtnTarget.disabled = false

    this.statusTarget.textContent = "Игра началась..."

    setTimeout(() => this.showNextStimulus(), 1200)
  }

  showNextStimulus() {
    if (!this.isGameActive || this.currentIndex >= this.sequenceValue.length) {
      this.finish()
      return
    }

    this.hasAnswered = false
    this.expectedMatch = false

    const currentIdx = this.currentIndex
    this.nBackIdx = currentIdx - this.nValue
    const current = this.sequenceValue[this.currentIndex]

    if (this.nBackIdx >= 0) {
      const nBack = this.sequenceValue[this.nBackIdx];
      this.expectedMatch = (current === nBack);
    }

    this.stimulusTarget.textContent = current

    // symbols animation
    this.stimulusTarget.classList.remove("animate-pop")
    void this.stimulusTarget.offsetWidth // force reflow
    this.stimulusTarget.classList.add("animate-pop")
  
    setTimeout(() => {
      this.checkIfMissed();
      this.stimulusTarget.textContent = "?"
      this.stimulusTarget.classList.remove("scale-110", "ring-4", "ring-violet-400")
      
      this.currentIndex++
      this.showNextStimulus()
    }, 1500)
  }

  checkIfMissed() {
    if (this.hasAnswered) return;

    if (this.expectedMatch) {
      this.errorCount++;   // False Negative
      this.flash("!bg-red-500");
    } else {
      // skip correct
      this.correctCount++;
    }

    this.updateStats();
  } 

  match() {
    if (!this.isGameActive || this.hasAnswered) return

    this.hasAnswered = true

    if (this.nBackIdx < 0 || !this.expectedMatch) {
      this.errorCount++;        // False Positive
      this.flash("!bg-red-500");
    } else {
      this.correctCount++;
      this.flash("!bg-emerald-500");
    }

    this.updateStats()
  }

  flash(colorClass) {
  this.stimulusTarget.classList.add(colorClass)

  setTimeout(() => {
    this.stimulusTarget.classList.remove(colorClass)
  }, 300)
}

  finish() {
    this.isGameActive = false
    this.startBtnTarget.disabled = false
    this.matchBtnTarget.disabled = true
    this.saveResults()
    this.statusTarget.textContent = `Игра окончена! Правильно: ${this.correctCount} | Ошибки: ${this.errorCount}`
  }

  updateStats() {
    this.correctTarget.textContent = this.correctCount
    this.errorsTarget.textContent = this.errorCount
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
