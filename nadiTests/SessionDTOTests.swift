import Testing
@testable import nadi
import Foundation

// MARK: - Round-trip encoding/decoding

@Test func encodeDecode_roundTrip() throws {
    let original = SessionDTO(
        from: MeditationSession(
            localDate: "2025-03-15",
            startTime: Date(timeIntervalSince1970: 1_000_000),
            totalDuration: 600,
            plannedDuration: 600,
            pranayamaDuration: 300,
            focusDuration: 300,
            weekNumber: 3,
            phaseDuration: 4
        )
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(SessionDTO.self, from: data)

    #expect(decoded.localDate == original.localDate)
    #expect(decoded.totalDuration == original.totalDuration)
    #expect(decoded.plannedDuration == original.plannedDuration)
    #expect(decoded.pranayamaDuration == original.pranayamaDuration)
    #expect(decoded.focusDuration == original.focusDuration)
    #expect(decoded.weekNumber == original.weekNumber)
    #expect(decoded.phaseDuration == original.phaseDuration)
    #expect(decoded.completed == original.completed)
    // Date comparison with tolerance for ISO8601 fractional seconds
    #expect(abs(decoded.startTime.timeIntervalSince(original.startTime)) < 1)
}

// MARK: - isValid() boundary cases

@Test func isValid_validDTO() {
    let dto = makeDTO(weekNumber: 3, phaseDuration: 4)
    #expect(dto.isValid())
}

@Test func isValid_weekTooLow() {
    let dto = makeDTO(weekNumber: 0)
    #expect(!dto.isValid())
}

@Test func isValid_weekTooHigh() {
    let dto = makeDTO(weekNumber: 7)
    #expect(!dto.isValid())
}

@Test func isValid_weekBoundaryMin() {
    let dto = makeDTO(weekNumber: 1)
    #expect(dto.isValid())
}

@Test func isValid_weekBoundaryMax() {
    let dto = makeDTO(weekNumber: 6)
    #expect(dto.isValid())
}

@Test func isValid_phaseDurationTooLow() {
    let dto = makeDTO(phaseDuration: 1)
    #expect(!dto.isValid())
}

@Test func isValid_phaseDurationTooHigh() {
    let dto = makeDTO(phaseDuration: 17)
    #expect(!dto.isValid())
}

@Test func isValid_phaseDurationBoundaryMin() {
    let dto = makeDTO(phaseDuration: 2)
    #expect(dto.isValid())
}

@Test func isValid_phaseDurationBoundaryMax() {
    let dto = makeDTO(phaseDuration: 16)
    #expect(dto.isValid())
}

@Test func isValid_negativeTotalDuration() {
    let dto = makeDTO(totalDuration: -1)
    #expect(!dto.isValid())
}

@Test func isValid_futureStartTime() {
    let dto = makeDTO(startTime: Date.distantFuture)
    #expect(!dto.isValid())
}

@Test func isValid_zeroPlannedDuration() {
    let dto = makeDTO(plannedDuration: 0)
    #expect(dto.isValid())
}

// MARK: - toSession()

@Test func toSession_mapsAllFields() {
    let dto = makeDTO(
        localDate: "2025-06-01",
        weekNumber: 5,
        phaseDuration: 8,
        totalDuration: 1200,
        plannedDuration: 1200
    )
    let session = dto.toSession()

    #expect(session.localDate == "2025-06-01")
    #expect(session.weekNumber == 5)
    #expect(session.phaseDuration == 8)
    #expect(session.totalDuration == 1200)
    #expect(session.plannedDuration == 1200)
    #expect(session.completed == true) // 1200 >= 1200/2
}

@Test func toSession_completedFlagFromQualification() {
    let dto = makeDTO(totalDuration: 100, plannedDuration: 600)
    let session = dto.toSession()
    #expect(session.completed == false) // 100 < 300
}

// MARK: - Helpers

private func makeDTO(
    localDate: String = "2025-03-15",
    startTime: Date = Date(timeIntervalSince1970: 1_000_000),
    weekNumber: Int = 3,
    phaseDuration: Int = 4,
    totalDuration: Int = 600,
    plannedDuration: Int = 600
) -> SessionDTO {
    SessionDTO(
        from: MeditationSession(
            localDate: localDate,
            startTime: startTime,
            totalDuration: totalDuration,
            plannedDuration: plannedDuration,
            pranayamaDuration: totalDuration,
            focusDuration: 0,
            weekNumber: weekNumber,
            phaseDuration: phaseDuration
        )
    )
}
