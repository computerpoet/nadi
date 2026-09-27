import Testing
@testable import nadi
import Foundation

@MainActor
private func freshSettings() -> AppSettings {
    let suite = "nadiTest-\(UUID().uuidString)"
    return AppSettings(defaults: UserDefaults(suiteName: suite)!)
}

// MARK: - countdownSeconds

@Test @MainActor func countdownSecondsDefault() {
    let s = freshSettings()
    #expect(s.countdownSeconds == 5)
}

@Test @MainActor func countdownSecondsClampedToMin3() {
    let s = freshSettings()
    s.countdownSeconds = 1
    #expect(s.countdownSeconds == 3)
}

@Test @MainActor func countdownSecondsClampedToMax10() {
    let s = freshSettings()
    s.countdownSeconds = 99
    #expect(s.countdownSeconds == 10)
}

@Test @MainActor func countdownSecondsValidValue() {
    let s = freshSettings()
    s.countdownSeconds = 7
    #expect(s.countdownSeconds == 7)
}

// MARK: - phaseDuration

@Test @MainActor func phaseDurationDefault() {
    let s = freshSettings()
    #expect(s.phaseDuration == 4)
}

@Test @MainActor func phaseDurationMinimum1() {
    let s = freshSettings()
    s.phaseDuration = 0
    #expect(s.phaseDuration == 1)
}

// MARK: - currentWeek

@Test @MainActor func currentWeekDefault() {
    let s = freshSettings()
    #expect(s.currentWeek == 1)
}

@Test @MainActor func currentWeekMinimum1() {
    let s = freshSettings()
    s.currentWeek = 0
    #expect(s.currentWeek == 1)
}

// MARK: - advanceWeek

@Test @MainActor func advanceWeekIncrements() {
    let s = freshSettings()
    s.currentWeek = 3
    s.advanceWeek()
    #expect(s.currentWeek == 4)
}

@Test @MainActor func advanceWeekCapsAt6() {
    let s = freshSettings()
    s.currentWeek = 6
    s.advanceWeek()
    #expect(s.currentWeek == 6)
}

// MARK: - Defaults

@Test @MainActor func tickModeDefault() {
    let s = freshSettings()
    #expect(s.tickMode == .all)
}

@Test @MainActor func timerDirectionDefault() {
    let s = freshSettings()
    #expect(s.timerDirection == .countdown)
}
