import Foundation

/// Pure state machine for session phase computation.
/// Returns (phase, command) tuples — no side effects, fully testable.
enum PhaseCalculator {
    enum Command: Equatable {
        case none
        case startAudio
        case endSession(totalElapsed: Double, qualified: Bool)
    }

    /// Compute the current session phase and any side-effect command
    /// from elapsed time and configuration. Pure function.
    static func computePhase(
        elapsed: Double,
        countdownSeconds: Int,
        actualPranayamaSeconds: Int,
        actualFocusSeconds: Int,
        phaseDuration: Int,
        hasFocusPhase: Bool
    ) -> (phase: SessionPhase, command: Command) {
        let countdownEnd = Double(countdownSeconds)
        let pranayamaEnd = countdownEnd + Double(actualPranayamaSeconds)
        let transitionEnd = pranayamaEnd + 3.0
        let focusEnd = transitionEnd + Double(actualFocusSeconds)

        if elapsed < countdownEnd {
            let remaining = Int(ceil(countdownEnd - elapsed))
            return (.countdown(remaining: remaining), .none)
        }

        if elapsed < pranayamaEnd {
            let pranayamaElapsed = elapsed - countdownEnd
            let totalCycles = actualPranayamaSeconds / (3 * phaseDuration)
            let cycleDuration = Double(3 * phaseDuration)
            let currentCycleIndex = min(Int(pranayamaElapsed / cycleDuration), totalCycles - 1)
            let withinCycle = pranayamaElapsed - Double(currentCycleIndex) * cycleDuration
            let phaseIndex = min(Int(withinCycle / Double(phaseDuration)), 2)
            let secondInPhase = Int(withinCycle) % phaseDuration

            let breathPhase: BreathPhase = switch phaseIndex {
            case 0: .inhale
            case 1: .hold
            default: .exhale
            }

            let phase = SessionPhase.pranayama(
                breathPhase: breathPhase,
                secondInPhase: phaseDuration - secondInPhase,
                cycle: currentCycleIndex + 1,
                totalCycles: totalCycles
            )
            return (phase, .startAudio)
        }

        if hasFocusPhase && elapsed < transitionEnd {
            return (.transition, .none)
        }

        if hasFocusPhase && elapsed < focusEnd {
            let focusElapsed = Int(elapsed - transitionEnd)
            return (.focus(elapsed: focusElapsed, total: actualFocusSeconds), .none)
        }

        // Session complete
        let totalElapsed = elapsed - countdownEnd
        return (.complete, .endSession(totalElapsed: totalElapsed, qualified: true))
    }

    /// Compute elapsed session time accounting for pauses.
    static func sessionElapsed(
        sessionStartTime: Date?,
        totalPauseSeconds: Double,
        isPaused: Bool,
        pauseStartTime: Date?,
        now: Date = Date()
    ) -> Double {
        guard let start = sessionStartTime else { return 0 }
        let wallElapsed = now.timeIntervalSince(start)
        let pauseAdjust = isPaused ? now.timeIntervalSince(pauseStartTime ?? now) : 0
        return wallElapsed - totalPauseSeconds - pauseAdjust
    }
}
