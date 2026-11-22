import { Controller } from "@hotwired/stimulus"
import { t, createTimers, submitResult } from "controllers/games/base"

export default class extends Controller {
  static targets = ["stimulus", "status", "startBtn", "matchBtn", "correct", "errors"]
  static values = {
    submitUrl: String,
    messages: Object,
    n: Number,                // difficulty level (N=2, N=3, ...)
    stimulusDuration: Number, // ms each stimulus stays on screen
    sequence: Array           // sequence of stimuli
  }

  connect() {
    this.timers = createTimers()
    this.resetGame()
  }

  disconnect() {
    this.timers.clearAll()
  }

  resetGame() {
    this.currentIndex = 0
    this.correctCount = 0
    this.errorCount = 0
    this.trials = []
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

    this.statusTarget.textContent = this.message("started")

    this.timers.set(() => this.showNextStimulus(), 1200)
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
  
    this.timers.set(() => {
      this.checkIfMissed();
      this.stimulusTarget.textContent = "?"
      this.stimulusTarget.classList.remove("scale-110", "ring-4", "ring-accent")
      
      this.currentIndex++
      this.showNextStimulus()
    }, this.stimulusDurationValue)
  }

  // Called when the stimulus time is over: one trial per stimulus is recorded,
  // also when the player did not press anything.
  recordTrial() {
    this.trials.push({ rt_ms: null, correct: this.hasAnswered === this.expectedMatch, phase: null, pressed: this.hasAnswered })
  }

  checkIfMissed() {
    this.recordTrial()
    if (this.hasAnswered) return;

    if (this.expectedMatch) {
      this.errorCount++;   // False Negative
      this.flash("!bg-danger");
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
      this.flash("!bg-danger");
    } else {
      this.correctCount++;
      this.flash("!bg-success");
    }

    this.updateStats()
  }

  flash(colorClass) {
    this.stimulusTarget.classList.add(colorClass)

    this.timers.set(() => {
      this.stimulusTarget.classList.remove(colorClass)
    }, 300)
  }

  finish() {
    this.isGameActive = false
    this.startBtnTarget.disabled = false
    this.matchBtnTarget.disabled = true
    this.saveResults()
    this.statusTarget.textContent = this.message("finished", { correct: this.correctCount, errors: this.errorCount })
  }

  updateStats() {
    this.correctTarget.textContent = this.correctCount
    this.errorsTarget.textContent = this.errorCount
  }

  // The server recounts "correct" from the stored sequence and the pressed flags.
  async saveResults() {
    await submitResult(this.submitUrlValue, { trials: this.trials })
  }

  message(key, vars) {
    return t(this.messagesValue, key, vars)
  }
}
