import { Controller } from "@hotwired/stimulus"
import { t, createTimers, submitResult } from "controllers/games/base"

export default class extends Controller {
  static targets = ["stimulus", "status", "buttonsContainer", "colorBtn", "startBtn", "correct", "errors"]
  static values = {
    submitUrl: String,
    messages: Object,
    sequence: Array,
    stimulusDuration: Number
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

    this.statusTarget.textContent = this.message("started")

    this.timers.set(() => this.showNextStimulus(), 1000)
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
    this.paintStimulus(this.currentColor)

    // symbols animation
    this.stimulusTarget.classList.remove("animate-pop")
    void this.stimulusTarget.offsetWidth // force reflow
    this.stimulusTarget.classList.add("animate-pop")

    this.enableButtons()
  
    this.timers.set(() => {
      this.checkIfMissed();
      this.stimulusTarget.textContent = "?"
      this.stimulusTarget.classList.remove("scale-110", "ring-4", "ring-accent")
      
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
      this.flash("!bg-danger");
    } else {
      this.correctCount++;
      this.flash("!bg-success");
    }

    this.updateStats()
    this.disableButtons()
  }
  
  checkIfMissed() {
    if (this.hasAnswered) return;

    this.errorCount++;
    this.flash("!bg-danger");
  }

  updateStats() {
    this.correctTarget.textContent = this.correctCount
    this.errorsTarget.textContent = this.errorCount
  }
  
  finish() {
    this.isGameActive = false
    this.statusTarget.textContent = this.message("finished", { correct: this.correctCount, errors: this.errorCount })
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

    this.timers.set(() => {
      this.stimulusTarget.classList.remove(colorClass)
    }, 300)
  }

  // The word is drawn in the stimulus color; the hue is the same in every theme.
  paintStimulus(colorName) {
    const classes = {
      red: "text-stimulus-red",
      green: "text-stimulus-green",
      blue: "text-stimulus-blue",
      yellow: "text-stimulus-yellow"
    }
    this.stimulusTarget.classList.remove(...Object.values(classes))
    const colorClass = classes[colorName?.toLowerCase()]
    if (colorClass) this.stimulusTarget.classList.add(colorClass)
  }

  // The server checks the totals against the stored sequence.
  async saveResults() {
    await submitResult(this.submitUrlValue, {
      correct: this.correctCount,
      errors: this.errorCount,
      total_trials: this.sequenceValue.length
    })
  }

  message(key, vars) {
    return t(this.messagesValue, key, vars)
  }
}
