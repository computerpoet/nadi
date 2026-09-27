import Foundation
import SwiftData

@Model
final class MeditationSession {
    var id: UUID
    /// Local date string "yyyy-MM-dd" for timezone-safe grouping, streaks, heat map.
    var localDate: String
    /// Full timestamp for sorting and range queries.
    var startTime: Date
    /// Actual seconds the user meditated.
    var totalDuration: Int
    /// Planned session duration in seconds (from program schedule at session start).
    var plannedDuration: Int
    /// Actual pranayama seconds completed.
    var pranayamaDuration: Int
    /// Actual focus meditation seconds completed.
    var focusDuration: Int
    /// Program week at session time.
    var weekNumber: Int
    /// Phase duration (seconds per inhale/hold/exhale) used.
    var phaseDuration: Int
    /// True if totalDuration >= plannedDuration / 2 (≥50% completion).
    /// Stored for SwiftData schema stability; set via SessionQualification.
    var completed: Bool

    init(
        localDate: String,
        startTime: Date,
        totalDuration: Int,
        plannedDuration: Int,
        pranayamaDuration: Int,
        focusDuration: Int,
        weekNumber: Int,
        phaseDuration: Int
    ) {
        self.id = UUID()
        self.localDate = localDate
        self.startTime = startTime
        self.totalDuration = totalDuration
        self.plannedDuration = plannedDuration
        self.pranayamaDuration = pranayamaDuration
        self.focusDuration = focusDuration
        self.weekNumber = weekNumber
        self.phaseDuration = phaseDuration
        self.completed = SessionQualification.isQualified(
            elapsedSeconds: totalDuration, plannedDuration: plannedDuration
        )
    }
}
