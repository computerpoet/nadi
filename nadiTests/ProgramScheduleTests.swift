import Testing
@testable import nadi

// MARK: - config(for:)

@Test(arguments: [
    (1, 10, 0),
    (2, 20, 0),
    (3, 10, 20),
    (4, 10, 30),
    (5, 10, 40),
    (6, 10, 50),
])
func configForWeek(week: Int, expectedPranayama: Int, expectedFocus: Int) {
    let config = ProgramSchedule.config(for: week)
    #expect(config.pranayamaMinutes == expectedPranayama)
    #expect(config.focusMinutes == expectedFocus)
}

@Test func configDefaultsToWeek6ForLargeValues() {
    let config = ProgramSchedule.config(for: 99)
    #expect(config.pranayamaMinutes == 10)
    #expect(config.focusMinutes == 50)
}

// MARK: - WeekConfig computed properties

@Test func weekConfigComputedProperties() {
    let config = ProgramSchedule.config(for: 3)
    #expect(config.pranayamaSeconds == 600)
    #expect(config.focusSeconds == 1200)
    #expect(config.totalSeconds == 1800)
    #expect(config.hasFocusPhase == true)
}

@Test func weekConfigNoFocusPhase() {
    let config = ProgramSchedule.config(for: 1)
    #expect(config.hasFocusPhase == false)
    #expect(config.focusSeconds == 0)
    #expect(config.totalSeconds == 600)
}

// MARK: - cycleCount

@Test(arguments: [
    (1, 4, 50),    // 600 / 12 = 50
    (1, 7, 28),    // 600 / 21 = 28.57 → 28
    (2, 4, 100),   // 1200 / 12 = 100
    (2, 5, 80),    // 1200 / 15 = 80
    (1, 1, 200),   // 600 / 3 = 200
])
func cycleCount(week: Int, phaseDuration: Int, expected: Int) {
    #expect(ProgramSchedule.cycleCount(week: week, phaseDuration: phaseDuration) == expected)
}

@Test func cycleCountZeroWhenPhaseTooLong() {
    // phaseDuration 300: one cycle = 900s, pranayama = 600s → 0
    #expect(ProgramSchedule.cycleCount(week: 1, phaseDuration: 300) == 0)
}

// MARK: - actualPranayamaSeconds

@Test func actualPranayamaSecondsExactDivision() {
    #expect(ProgramSchedule.actualPranayamaSeconds(week: 1, phaseDuration: 4) == 600)
}

@Test func actualPranayamaSecondsWithRemainder() {
    // 600 / 21 = 28 cycles → 28 * 21 = 588
    #expect(ProgramSchedule.actualPranayamaSeconds(week: 1, phaseDuration: 7) == 588)
}

@Test func actualPranayamaSecondsZeroWhenNoCycles() {
    #expect(ProgramSchedule.actualPranayamaSeconds(week: 1, phaseDuration: 300) == 0)
}

// MARK: - leftoverSeconds

@Test func leftoverSecondsZeroWhenExact() {
    #expect(ProgramSchedule.leftoverSeconds(week: 1, phaseDuration: 4) == 0)
}

@Test func leftoverSecondsNonZero() {
    // 600 - 588 = 12
    #expect(ProgramSchedule.leftoverSeconds(week: 1, phaseDuration: 7) == 12)
}

@Test func leftoverSecondsFullWhenNoCycles() {
    #expect(ProgramSchedule.leftoverSeconds(week: 1, phaseDuration: 300) == 600)
}
