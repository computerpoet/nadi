import Foundation

/// Codable transfer object for MeditationSession import/export.
/// Separate from @Model to avoid SwiftData/Codable conflicts.
struct SessionDTO: Codable {
    let localDate: String
    let startTime: Date
    let totalDuration: Int
    let plannedDuration: Int
    let pranayamaDuration: Int
    let focusDuration: Int
    let weekNumber: Int
    let phaseDuration: Int
    let completed: Bool

    init(from session: MeditationSession) {
        self.localDate = session.localDate
        self.startTime = session.startTime
        self.totalDuration = session.totalDuration
        self.plannedDuration = session.plannedDuration
        self.pranayamaDuration = session.pranayamaDuration
        self.focusDuration = session.focusDuration
        self.weekNumber = session.weekNumber
        self.phaseDuration = session.phaseDuration
        self.completed = session.completed
    }

    /// Validate bounds before converting to a model object.
    func isValid() -> Bool {
        (1...6).contains(weekNumber)
            && (2...16).contains(phaseDuration)
            && totalDuration >= 0
            && plannedDuration >= 0
            && pranayamaDuration >= 0
            && focusDuration >= 0
            && startTime <= Date()
    }

    func toSession() -> MeditationSession {
        MeditationSession(
            localDate: localDate,
            startTime: startTime,
            totalDuration: totalDuration,
            plannedDuration: plannedDuration,
            pranayamaDuration: pranayamaDuration,
            focusDuration: focusDuration,
            weekNumber: weekNumber,
            phaseDuration: phaseDuration
        )
    }
}
