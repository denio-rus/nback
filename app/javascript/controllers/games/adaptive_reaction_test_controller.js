import { Controller } from "@hotwired/stimulus"
import { t, createTimers, submitResult } from "controllers/games/base"

// Three parts, two buttons. The circle turns red or green after a pause; the
// rule (which button answers which color) is shown before each part and stays
// on screen during it. The rule changes in part 2.
// Full class names, so that Tailwind finds them when it scans the files.
const STIMULUS_CLASSES = { red: "bg-stimulus-red", green: "bg-stimulus-green" }

export default class extends Controller {
  static targets = ["circle", "status", "rule", "startBtn", "continueBtn", "answerButtons", "answerBtn"]
  static values = {
    submitUrl: String,
    messages: Object,
    sequence: Object,      // { round_1: [[delay_ms, color], ...], ... }
    rules: Object,         // { "1": { red: "a", green: "b" }, ... }
    stimulusDuration: Number
  }

  connect() {
    this.timers = createTimers()
    this.part = 0
    this.trials = []
  }

  disconnect() {
    this.timers.clearAll()
  }

  start() {
    this.startBtnTarget.classList.add("hidden")
    this.part = 0
    this.trials = []
    this.showRuleForNextPart()
  }

  // The player reads the rule and starts the part when ready.
  showRuleForNextPart() {
    this.part++
    this.index = 0
    this.answerButtonsTarget.classList.add("hidden")
    this.continueBtnTarget.classList.remove("hidden")
    this.showRule()
    this.statusTarget.textContent = this.message("part_intro", { part: this.part, total: this.partCount })
  }

  beginPart() {
    this.continueBtnTarget.classList.add("hidden")
    this.answerButtonsTarget.classList.remove("hidden")
    this.setAnswersEnabled(false)
    this.statusTarget.textContent = this.message("part", { part: this.part, total: this.partCount })
    this.timers.set(() => this.runNextTrial(), 1000)
  }

  runNextTrial() {
    const stimuli = this.partStimuli
    if (this.index >= stimuli.length) {
      this.finishPart()
      return
    }

    const [delay, color] = stimuli[this.index]
    this.currentColor = color
    this.waitingForAnswer = false
    this.showIdle()
    this.setAnswersEnabled(false)

    this.timers.set(() => {
      this.showStimulus(color)
      this.shownAt = performance.now()
      this.waitingForAnswer = true
      this.setAnswersEnabled(true)

      this.timeout = this.timers.set(() => this.record(null), this.stimulusDurationValue)
    }, delay)
  }

  // A press before the circle appears is ignored: the buttons are disabled then.
  answer(event) {
    if (!this.waitingForAnswer) return

    this.timers.clear(this.timeout)
    this.record(event.currentTarget.dataset.button)
  }

  // One trial per stimulus; the server recomputes "correct" from shown, pressed and the rule.
  record(pressed) {
    if (!this.waitingForAnswer) return
    this.waitingForAnswer = false

    const rt = pressed === null ? null : Math.round(performance.now() - this.shownAt)
    this.trials.push({
      rt_ms: rt,
      correct: pressed !== null && this.rule[this.currentColor] === pressed,
      phase: this.part,
      shown: this.currentColor,
      pressed
    })
    this.index++
    this.showIdle()
    this.setAnswersEnabled(false)
    this.timers.set(() => this.runNextTrial(), 400)
  }

  finishPart() {
    if (this.part < this.partCount) {
      this.showRuleForNextPart()
    } else {
      this.finish()
    }
  }

  finish() {
    this.answerButtonsTarget.classList.add("hidden")
    this.statusTarget.textContent = this.message("finished")
    this.saveResults()
  }

  async saveResults() {
    await submitResult(this.submitUrlValue, { trials: this.trials })
  }

  showRule() {
    const rule = this.rule
    this.ruleTarget.textContent = this.message("rule", {
      red: this.buttonLabel(rule.red),
      green: this.buttonLabel(rule.green)
    })
  }

  buttonLabel(button) {
    return this.message(`buttons.${button}`)
  }

  // The circle is grey while waiting and takes the stimulus color when shown.
  showIdle() {
    this.circleTarget.classList.remove(...Object.values(STIMULUS_CLASSES))
    this.circleTarget.classList.add("bg-ink-muted")
  }

  showStimulus(color) {
    this.circleTarget.classList.remove("bg-ink-muted")
    this.circleTarget.classList.add(STIMULUS_CLASSES[color])
  }

  setAnswersEnabled(enabled) {
    this.answerBtnTargets.forEach((button) => (button.disabled = !enabled))
  }

  get partCount() {
    return Object.keys(this.sequenceValue).length
  }

  get partStimuli() {
    return this.sequenceValue[`round_${this.part}`] || []
  }

  get rule() {
    return this.rulesValue[String(this.part)]
  }

  message(key, vars) {
    return t(this.messagesValue, key, vars)
  }
}
