import Foundation

enum ProgramSchedule {
    struct WeekConfig: Sendable {
        let pranayamaMinutes: Int
        let focusMinutes: Int

        var pranayamaSeconds: Int { pranayamaMinutes * 60 }
        var focusSeconds: Int { focusMinutes * 60 }
        var totalSeconds: Int { pranayamaSeconds + focusSeconds }
        var hasFocusPhase: Bool { focusMinutes > 0 }
    }

    static func config(for week: Int) -> WeekConfig {
        switch week {
        case 1: WeekConfig(pranayamaMinutes: 10, focusMinutes: 0)
        case 2: WeekConfig(pranayamaMinutes: 20, focusMinutes: 0)
        case 3: WeekConfig(pranayamaMinutes: 10, focusMinutes: 20)
        case 4: WeekConfig(pranayamaMinutes: 10, focusMinutes: 30)
        case 5: WeekConfig(pranayamaMinutes: 10, focusMinutes: 40)
        default: WeekConfig(pranayamaMinutes: 10, focusMinutes: 50) // week 6+
        }
    }

    /// Total breathing cycles that fit in the pranayama duration.
    /// One cycle = 3 * phaseDuration seconds (inhale + hold + exhale).
    /// Partial cycles are dropped.
    static func cycleCount(week: Int, phaseDuration: Int) -> Int {
        precondition(phaseDuration >= 1)
        let cycleDuration = 3 * phaseDuration
        return config(for: week).pranayamaSeconds / cycleDuration
    }

    /// Actual pranayama duration after dropping partial cycles.
    static func actualPranayamaSeconds(week: Int, phaseDuration: Int) -> Int {
        cycleCount(week: week, phaseDuration: phaseDuration) * 3 * phaseDuration
    }

    /// Leftover seconds from dropped partial cycles, added to focus phase.
    static func leftoverSeconds(week: Int, phaseDuration: Int) -> Int {
        let planned = config(for: week).pranayamaSeconds
        let actual = actualPranayamaSeconds(week: week, phaseDuration: phaseDuration)
        return planned - actual
    }
}
