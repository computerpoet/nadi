import Foundation

enum TickMode: String, CaseIterable, Identifiable, Sendable {
    case all = "all"
    case phaseOnly = "phaseOnly"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All ticks"
        case .phaseOnly: "Phase ticks only"
        }
    }
}

enum TimerDirection: String, CaseIterable, Identifiable, Sendable {
    case countdown = "countdown"
    case countUp = "countUp"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .countdown: "Countdown"
        case .countUp: "Count up"
        }
    }
}

/// App-wide settings backed by UserDefaults.
///
/// Uses `@Observable` with stored properties + `didSet` → UserDefaults persistence.
///
/// **Why not `@AppStorage`?** `@AppStorage` is a `DynamicProperty` (view-level).
/// Inside `@Observable`, the macro marks it `@ObservationIgnored`, silently breaking
/// SwiftUI observation — writes succeed but views never re-render. Apple's migration
/// guide and WWDC 2023 "Discover Observation" don't address this gap.
///
/// **`didSet` clamping caveat:** `@Observable` wraps setters. Re-assigning `self.prop`
/// in `didSet` re-triggers the setter. Guard with `if value < min { value = min; return }`
/// so the second `didSet` invocation falls through to `defaults.set()` without looping.
///
/// The `defaults` injection enables testing with isolated `UserDefaults` suites.
@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var currentWeek: Int = 1 {
        didSet {
            if currentWeek < 1 { currentWeek = 1; return }
            defaults.set(currentWeek, forKey: "currentWeek")
        }
    }
    var weekStartDate: String = "" {
        didSet { defaults.set(weekStartDate, forKey: "weekStartDate") }
    }
    var phaseDuration: Int = 4 {
        didSet {
            if phaseDuration < 1 { phaseDuration = 1; return }
            defaults.set(phaseDuration, forKey: "phaseDuration")
        }
    }
    var tickMode: TickMode = .all {
        didSet { defaults.set(tickMode.rawValue, forKey: "tickMode") }
    }
    var timerDirection: TimerDirection = .countdown {
        didSet { defaults.set(timerDirection.rawValue, forKey: "timerDirection") }
    }
    var countdownSeconds: Int = 5 {
        didSet {
            let clamped = max(3, min(10, countdownSeconds))
            if countdownSeconds != clamped { countdownSeconds = clamped; return }
            defaults.set(countdownSeconds, forKey: "countdownSeconds")
        }
    }
    var onboardingComplete: Bool = false {
        didSet { defaults.set(onboardingComplete, forKey: "onboardingComplete") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load from UserDefaults, falling back to property defaults.
        let week = defaults.integer(forKey: "currentWeek")
        currentWeek = week == 0 ? 1 : max(1, week)

        weekStartDate = defaults.string(forKey: "weekStartDate") ?? DateFormatting.todayString()

        let phase = defaults.integer(forKey: "phaseDuration")
        phaseDuration = phase == 0 ? 4 : max(1, phase)

        tickMode = TickMode(rawValue: defaults.string(forKey: "tickMode") ?? "") ?? .all
        timerDirection = TimerDirection(rawValue: defaults.string(forKey: "timerDirection") ?? "") ?? .countdown

        let countdown = defaults.integer(forKey: "countdownSeconds")
        countdownSeconds = countdown == 0 ? 5 : max(3, min(10, countdown))

        onboardingComplete = defaults.bool(forKey: "onboardingComplete")
    }

    /// Advance to the next week if 7 consecutive days have been completed.
    func checkWeekAdvance(completedDates: Set<String>) {
        guard currentWeek < 6 else { return }
        let days = StreakCalculator.consecutiveDaysSince(
            startDate: weekStartDate,
            completedDates: completedDates
        )
        if days >= 7 {
            advanceWeek()
        }
    }

    func advanceWeek() {
        if currentWeek < 6 {
            currentWeek += 1
        }
        weekStartDate = DateFormatting.todayString()
    }
}
