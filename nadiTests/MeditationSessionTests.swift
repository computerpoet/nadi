import Testing
@testable import nadi
import Foundation

// MARK: - Completion boundary

@Test(arguments: [
    (300, 600, true),    // exactly 50%
    (301, 600, true),    // just over
    (299, 600, false),   // just under
    (600, 600, true),    // 100%
    (0, 600, false),     // 0%
    (0, 0, true),        // 0 >= 0
])
func completionBoundary(totalDuration: Int, plannedDuration: Int, expected: Bool) {
    let session = MeditationSession(
        localDate: "2025-01-01",
        startTime: Date(),
        totalDuration: totalDuration,
        plannedDuration: plannedDuration,
        pranayamaDuration: totalDuration,
        focusDuration: 0,
        weekNumber: 1,
        phaseDuration: 4
    )
    #expect(session.completed == expected)
}

@Test func integerDivisionEdgeCase() {
    // plannedDuration=1 → 1/2 = 0 in Swift integer division
    // So totalDuration=0 >= 0 → completed = true
    let session = MeditationSession(
        localDate: "2025-01-01",
        startTime: Date(),
        totalDuration: 0,
        plannedDuration: 1,
        pranayamaDuration: 0,
        focusDuration: 0,
        weekNumber: 1,
        phaseDuration: 4
    )
    #expect(session.completed == true, "Integer division: 1/2 = 0, so 0 >= 0 is true")
}

// MARK: - InProgressSession

@Test func elapsedSecondsCalculation() {
    let start = Date(timeIntervalSince1970: 1000)
    let session = InProgressSession(
        startTime: start,
        plannedDuration: 600,
        weekNumber: 1,
        phaseDuration: 4
    )
    session.lastActiveTimestamp = Date(timeIntervalSince1970: 1300)
    #expect(session.elapsedSeconds == 300)
}

@Test func inProgressIsCompletedBoundary() {
    let start = Date(timeIntervalSince1970: 1000)
    let session = InProgressSession(
        startTime: start,
        plannedDuration: 600,
        weekNumber: 1,
        phaseDuration: 4
    )

    session.lastActiveTimestamp = Date(timeIntervalSince1970: 1299)
    #expect(session.isCompleted == false)

    session.lastActiveTimestamp = Date(timeIntervalSince1970: 1300)
    #expect(session.isCompleted == true)
}
