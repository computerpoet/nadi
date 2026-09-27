import Testing
@testable import nadi
import Foundation
import SwiftData

/// In-memory ModelContainer for isolated persistence tests.
private func testContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: MeditationSession.self, InProgressSession.self,
        configurations: config
    )
}

private func makeMeditationSession(
    localDate: String = "2025-03-15",
    startTime: Date = Date(timeIntervalSince1970: 1_000_000),
    totalDuration: Int = 600,
    plannedDuration: Int = 600,
    weekNumber: Int = 1,
    phaseDuration: Int = 4
) -> MeditationSession {
    MeditationSession(
        localDate: localDate,
        startTime: startTime,
        totalDuration: totalDuration,
        plannedDuration: plannedDuration,
        pranayamaDuration: totalDuration,
        focusDuration: 0,
        weekNumber: weekNumber,
        phaseDuration: phaseDuration
    )
}

// MARK: - MeditationSession CRUD

@Test @MainActor func insertAndFetchSession() throws {
    let container = try testContainer()
    let context = container.mainContext

    let session = makeMeditationSession()
    context.insert(session)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<MeditationSession>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.totalDuration == 600)
}

@Test @MainActor func deleteSession() throws {
    let container = try testContainer()
    let context = container.mainContext

    let session = makeMeditationSession()
    context.insert(session)
    try context.save()

    context.delete(session)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<MeditationSession>())
    #expect(fetched.isEmpty)
}

@Test @MainActor func multipleSessions() throws {
    let container = try testContainer()
    let context = container.mainContext

    for i in 0..<5 {
        let session = makeMeditationSession(
            startTime: Date(timeIntervalSince1970: Double(1_000_000 + i * 1000))
        )
        context.insert(session)
    }
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<MeditationSession>())
    #expect(fetched.count == 5)
}

// MARK: - InProgressSession Lifecycle

@Test @MainActor func inProgressCreateUpdateDelete() throws {
    let container = try testContainer()
    let context = container.mainContext

    // Create
    let start = Date(timeIntervalSince1970: 1000)
    let record = InProgressSession(
        startTime: start,
        plannedDuration: 600,
        weekNumber: 1,
        phaseDuration: 4
    )
    context.insert(record)
    try context.save()

    var fetched = try context.fetch(FetchDescriptor<InProgressSession>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.elapsedSeconds == 0)

    // Update timestamp (simulate heartbeat)
    record.lastActiveTimestamp = Date(timeIntervalSince1970: 1300)
    try context.save()

    fetched = try context.fetch(FetchDescriptor<InProgressSession>())
    #expect(fetched.first?.elapsedSeconds == 300)
    #expect(fetched.first?.isCompleted == true) // 300 >= 600/2

    // Delete (normal session completion)
    context.delete(record)
    try context.save()

    fetched = try context.fetch(FetchDescriptor<InProgressSession>())
    #expect(fetched.isEmpty)
}

// MARK: - Crash Recovery Simulation

@Test @MainActor func crashRecoveryQualifiedSession() throws {
    let container = try testContainer()
    let context = container.mainContext

    // Simulate crash: InProgressSession left behind
    let start = Date(timeIntervalSince1970: 1000)
    let record = InProgressSession(
        startTime: start,
        plannedDuration: 600,
        weekNumber: 2,
        phaseDuration: 4
    )
    record.lastActiveTimestamp = Date(timeIntervalSince1970: 1350) // 350s elapsed, > 50%
    context.insert(record)
    try context.save()

    #expect(record.isCompleted == true)

    // Recovery: convert to MeditationSession
    let localDate = DateFormatting.localDateString(from: start)
    let recovered = MeditationSession(
        localDate: localDate,
        startTime: start,
        totalDuration: record.elapsedSeconds,
        plannedDuration: record.plannedDuration,
        pranayamaDuration: record.elapsedSeconds,
        focusDuration: 0,
        weekNumber: record.weekNumber,
        phaseDuration: record.phaseDuration
    )
    context.insert(recovered)
    context.delete(record)
    try context.save()

    let sessions = try context.fetch(FetchDescriptor<MeditationSession>())
    #expect(sessions.count == 1)
    #expect(sessions.first?.totalDuration == 350)
    #expect(sessions.first?.completed == true)

    let inProgress = try context.fetch(FetchDescriptor<InProgressSession>())
    #expect(inProgress.isEmpty)
}

@Test @MainActor func crashRecoveryUnqualifiedSession() throws {
    let container = try testContainer()
    let context = container.mainContext

    let start = Date(timeIntervalSince1970: 1000)
    let record = InProgressSession(
        startTime: start,
        plannedDuration: 600,
        weekNumber: 1,
        phaseDuration: 4
    )
    record.lastActiveTimestamp = Date(timeIntervalSince1970: 1100) // 100s elapsed, < 50%
    context.insert(record)
    try context.save()

    #expect(record.isCompleted == false)

    // Unqualified: just delete, don't create MeditationSession
    context.delete(record)
    try context.save()

    let sessions = try context.fetch(FetchDescriptor<MeditationSession>())
    #expect(sessions.isEmpty)
}
