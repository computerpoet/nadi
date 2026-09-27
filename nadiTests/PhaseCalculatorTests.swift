import Testing
import Foundation
@testable import nadi

struct PhaseCalculatorTests {
    // Standard week 1 config: 5 min pranayama (300s), no focus
    // With phaseDuration=4: actualPranayama = 5 cycles * 12s = 60s... let's use real values
    // Week 1: 5 min pranayama, 0 focus, phaseDuration=4
    // actualPranayamaSeconds = cycles * 3 * 4 where cycles = 300 / 12 = 25 → 300s
    let countdownSeconds = 5
    let phaseDuration = 4

    // Week 1: pranayama only
    let actualPranayamaW1 = 300
    let actualFocusW1 = 0
    let hasFocusW1 = false

    // Week 3: pranayama + focus (5 min prana, 10 min focus = 600s actual)
    let actualPranayamaW3 = 300
    let actualFocusW3 = 600
    let hasFocusW3 = true

    // MARK: - Countdown Phase

    @Test func countdownAtStart() {
        let (phase, command) = PhaseCalculator.computePhase(
            elapsed: 0.0,
            countdownSeconds: countdownSeconds,
            actualPranayamaSeconds: actualPranayamaW1,
            actualFocusSeconds: actualFocusW1,
            phaseDuration: phaseDuration,
            hasFocusPhase: hasFocusW1
        )
        #expect(phase == .countdown(remaining: 5))
        #expect(command == .none)
    }

    @Test func countdownMidway() {
        let (phase, command) = PhaseCalculator.computePhase(
            elapsed: 2.3,
            countdownSeconds: countdownSeconds,
            actualPranayamaSeconds: actualPranayamaW1,
            actualFocusSeconds: actualFocusW1,
            phaseDuration: phaseDuration,
            hasFocusPhase: hasFocusW1
        )
        #expect(phase == .countdown(remaining: 3))
        #expect(command == .none)
    }

    // MARK: - Pranayama Phase

    @Test func pranayamaStartsAfterCountdown() {
        let (phase, command) = PhaseCalculator.computePhase(
            elapsed: 5.0,
            countdownSeconds: countdownSeconds,
            actualPranayamaSeconds: actualPranayamaW1,
            actualFocusSeconds: actualFocusW1,
            phaseDuration: phaseDuration,
            hasFocusPhase: hasFocusW1
        )
        // At t=5.0, pranayamaElapsed=0 → cycle 0, phase 0 (inhale), secondInPhase=4
        #expect(phase == .pranayama(breathPhase: .inhale, secondInPhase: 4, cycle: 1, totalCycles: 25))
        #expect(command == .startAudio)
    }

    @Test func pranayamaHoldPhase() {
        // After countdown (5s) + one inhale phase (4s) = elapsed 9.0
        let (phase, _) = PhaseCalculator.computePhase(
            elapsed: 9.0,
            countdownSeconds: countdownSeconds,
            actualPranayamaSeconds: actualPranayamaW1,
            actualFocusSeconds: actualFocusW1,
            phaseDuration: phaseDuration,
            hasFocusPhase: hasFocusW1
        )
        #expect(phase == .pranayama(breathPhase: .hold, secondInPhase: 4, cycle: 1, totalCycles: 25))
    }

    @Test func pranayamaExhalePhase() {
        // After countdown (5s) + inhale (4s) + hold (4s) = elapsed 13.0
        let (phase, _) = PhaseCalculator.computePhase(
            elapsed: 13.0,
            countdownSeconds: countdownSeconds,
            actualPranayamaSeconds: actualPranayamaW1,
            actualFocusSeconds: actualFocusW1,
            phaseDuration: phaseDuration,
            hasFocusPhase: hasFocusW1
        )
        #expect(phase == .pranayama(breathPhase: .exhale, secondInPhase: 4, cycle: 1, totalCycles: 25))
    }

    @Test func pranayamaSecondCycle() {
        // After countdown (5s) + one full cycle (12s) = elapsed 17.0
        let (phase, _) = PhaseCalculator.computePhase(
            elapsed: 17.0,
            countdownSeconds: countdownSeconds,
            actualPranayamaSeconds: actualPranayamaW1,
            actualFocusSeconds: actualFocusW1,
            phaseDuration: phaseDuration,
            hasFocusPhase: hasFocusW1
        )
        #expect(phase == .pranayama(breathPhase: .inhale, secondInPhase: 4, cycle: 2, totalCycles: 25))
    }

    @Test func pranayamaAlwaysStartsAudio() {
        // Any time during pranayama should emit .startAudio
        let (_, command) = PhaseCalculator.computePhase(
            elapsed: 100.0,
            countdownSeconds: countdownSeconds,
            actualPranayamaSeconds: actualPranayamaW1,
            actualFocusSeconds: actualFocusW1,
            phaseDuration: phaseDuration,
            hasFocusPhase: hasFocusW1
        )
        #expect(command == .startAudio)
    }

    // MARK: - Transition Phase (focus weeks only)

    @Test func transitionPhaseAfterPranayama() {
        // countdown(5) + pranayama(300) = 305. Transition is 305..308
        let (phase, command) = PhaseCalculator.computePhase(
            elapsed: 306.0,
            countdownSeconds: countdownSeconds,
            actualPranayamaSeconds: actualPranayamaW3,
            actualFocusSeconds: actualFocusW3,
            phaseDuration: phaseDuration,
            hasFocusPhase: hasFocusW3
        )
        #expect(phase == .transition)
        #expect(command == .none)
    }

    // MARK: - Focus Phase

    @Test func focusPhaseStart() {
        // countdown(5) + pranayama(300) + transition(3) = 308
        let (phase, command) = PhaseCalculator.computePhase(
            elapsed: 308.0,
            countdownSeconds: countdownSeconds,
            actualPranayamaSeconds: actualPranayamaW3,
            actualFocusSeconds: actualFocusW3,
            phaseDuration: phaseDuration,
            hasFocusPhase: hasFocusW3
        )
        #expect(phase == .focus(elapsed: 0, total: 600))
        #expect(command == .none)
    }

    @Test func focusPhaseMidway() {
        let (phase, _) = PhaseCalculator.computePhase(
            elapsed: 608.0, // 308 + 300
            countdownSeconds: countdownSeconds,
            actualPranayamaSeconds: actualPranayamaW3,
            actualFocusSeconds: actualFocusW3,
            phaseDuration: phaseDuration,
            hasFocusPhase: hasFocusW3
        )
        #expect(phase == .focus(elapsed: 300, total: 600))
    }

    // MARK: - Session Complete

    @Test func sessionCompleteNoFocus() {
        // Week 1: countdown(5) + pranayama(300) = 305
        let (phase, command) = PhaseCalculator.computePhase(
            elapsed: 305.0,
            countdownSeconds: countdownSeconds,
            actualPranayamaSeconds: actualPranayamaW1,
            actualFocusSeconds: actualFocusW1,
            phaseDuration: phaseDuration,
            hasFocusPhase: hasFocusW1
        )
        #expect(phase == .complete)
        #expect(command == .endSession(totalElapsed: 300.0, qualified: true))
    }

    @Test func sessionCompleteWithFocus() {
        // Week 3: countdown(5) + pranayama(300) + transition(3) + focus(600) = 908
        let (phase, command) = PhaseCalculator.computePhase(
            elapsed: 908.0,
            countdownSeconds: countdownSeconds,
            actualPranayamaSeconds: actualPranayamaW3,
            actualFocusSeconds: actualFocusW3,
            phaseDuration: phaseDuration,
            hasFocusPhase: hasFocusW3
        )
        #expect(phase == .complete)
        #expect(command == .endSession(totalElapsed: 903.0, qualified: true))
    }

    // MARK: - sessionElapsed

    @Test func sessionElapsedBasic() {
        let start = Date(timeIntervalSinceNow: -100)
        let elapsed = PhaseCalculator.sessionElapsed(
            sessionStartTime: start,
            totalPauseSeconds: 0,
            isPaused: false,
            pauseStartTime: nil
        )
        #expect(elapsed >= 99.9 && elapsed <= 100.1)
    }

    @Test func sessionElapsedWithPause() {
        let start = Date(timeIntervalSinceNow: -100)
        let elapsed = PhaseCalculator.sessionElapsed(
            sessionStartTime: start,
            totalPauseSeconds: 30,
            isPaused: false,
            pauseStartTime: nil
        )
        #expect(elapsed >= 69.9 && elapsed <= 70.1)
    }

    @Test func sessionElapsedWhilePaused() {
        let now = Date()
        let start = now.addingTimeInterval(-100)
        let pauseStart = now.addingTimeInterval(-20)
        let elapsed = PhaseCalculator.sessionElapsed(
            sessionStartTime: start,
            totalPauseSeconds: 10,
            isPaused: true,
            pauseStartTime: pauseStart,
            now: now
        )
        // 100 wall - 10 prior pause - 20 current pause = 70
        #expect(elapsed >= 69.9 && elapsed <= 70.1)
    }

    @Test func sessionElapsedNilStart() {
        let elapsed = PhaseCalculator.sessionElapsed(
            sessionStartTime: nil,
            totalPauseSeconds: 0,
            isPaused: false,
            pauseStartTime: nil
        )
        #expect(elapsed == 0)
    }
}
