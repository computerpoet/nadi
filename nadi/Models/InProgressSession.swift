import Foundation
import SwiftData

/// Temporary record written at session start, updated every 30s.
/// Used to recover from app termination mid-session.
/// Deleted on normal session completion.
@Model
final class InProgressSession {
    var id: UUID
    var startTime: Date
    var plannedDuration: Int
    /// Updated every 30 seconds while the session is active.
    var lastActiveTimestamp: Date
    var weekNumber: Int
    var phaseDuration: Int

    init(
        startTime: Date,
        plannedDuration: Int,
        weekNumber: Int,
        phaseDuration: Int
    ) {
        self.id = UUID()
        self.startTime = startTime
        self.plannedDuration = plannedDuration
        self.lastActiveTimestamp = startTime
        self.weekNumber = weekNumber
        self.phaseDuration = phaseDuration
    }

    /// Elapsed time based on last known active timestamp (not wall clock).
    var elapsedSeconds: Int {
        Int(lastActiveTimestamp.timeIntervalSince(startTime))
    }

    var isCompleted: Bool {
        SessionQualification.isQualified(elapsedSeconds: elapsedSeconds, plannedDuration: plannedDuration)
    }
}
