import Foundation

/// Single source of truth for the "≥50% completion" threshold.
/// Used by SessionState, MeditationSession, InProgressSession, and crash recovery.
enum SessionQualification {
    /// A session qualifies if the user completed at least half the planned duration.
    /// Uses integer division (consistent with Swift's default) — a 21-minute plan
    /// requires 10 seconds (21/2 = 10), not 10.5.
    static func isQualified(elapsedSeconds: Int, plannedDuration: Int) -> Bool {
        elapsedSeconds >= plannedDuration / 2
    }
}
