import Testing
@testable import nadi

// MARK: - Helpers

private func makeTimeline(
    week: Int = 1,
    phaseDuration: Int = 4,
    tickMode: TickMode = .all,
    pranayamaOverride: Int? = nil,
    focusOverride: Int? = nil
) -> [TickEvent] {
    let config = ProgramSchedule.config(for: week)
    let actualPrana = pranayamaOverride ?? ProgramSchedule.actualPranayamaSeconds(week: week, phaseDuration: phaseDuration)
    let actualFocus = focusOverride ?? (config.hasFocusPhase ? config.focusSeconds + ProgramSchedule.leftoverSeconds(week: week, phaseDuration: phaseDuration) : 0)
    return TickScheduler.computeEventTimeline(
        weekConfig: config,
        phaseDuration: phaseDuration,
        tickMode: tickMode,
        actualPranayamaSeconds: actualPrana,
        actualFocusSeconds: actualFocus
    )
}

// MARK: - Basic structure

@Test func firstEventIsStressedTick() {
    let events = makeTimeline()
    #expect(events.first?.kind == .stressed)
    #expect(events.first?.offsetSeconds == 0)
}

@Test func closingDoubleBell() {
    let events = makeTimeline(week: 1) // no focus phase → closing at pranayama end
    let lastTwo = Array(events.suffix(2))
    #expect(lastTwo[0].kind == .bell)
    #expect(lastTwo[1].kind == .bell)
    #expect(lastTwo[1].offsetSeconds - lastTwo[0].offsetSeconds == 1.5)
}

@Test func eventsAreSortedByTime() {
    let events = makeTimeline(week: 3)
    for i in 1..<events.count {
        #expect(events[i].offsetSeconds >= events[i - 1].offsetSeconds,
                "Event \(i) at \(events[i].offsetSeconds) is before event \(i-1) at \(events[i-1].offsetSeconds)")
    }
}

// MARK: - Tick modes

@Test func stressedTicksAtPhaseStarts() {
    // 1 cycle (12s = 3 * 4), 3 phases → 3 stressed ticks
    let events = makeTimeline(pranayamaOverride: 12)
    let stressed = events.filter { $0.kind == .stressed }
    #expect(stressed.count == 3)
    #expect(stressed.map(\.offsetSeconds) == [0, 4, 8])
}

@Test func phaseOnlyModeNoRegularTicks() {
    let events = makeTimeline(tickMode: .phaseOnly, pranayamaOverride: 12)
    let ticks = events.filter { $0.kind == .tick }
    #expect(ticks.isEmpty)
}

@Test func allModeHasRegularTicks() {
    let events = makeTimeline(tickMode: .all, pranayamaOverride: 12)
    let ticks = events.filter { $0.kind == .tick }
    // 1 cycle, 3 phases, 4 seconds each: 3 regular ticks per phase = 9
    #expect(ticks.count == 9)
}

// MARK: - Bell placement

@Test func pranayamaOnlyHasClosingDoubleBellOnly() {
    // Only closing double bell = 2 bells total (no opening, no transition)
    let events = makeTimeline(week: 1, tickMode: .phaseOnly, pranayamaOverride: 12, focusOverride: 0)
    let bells = events.filter { $0.kind == .bell }
    #expect(bells.count == 2)
}

@Test func focusWeekHasClosingDoubleBellOnly() {
    // Week 3 has focus phase — should only have closing double bell, no transition/opening
    let events = makeTimeline(week: 3)
    let bells = events.filter { $0.kind == .bell }
    #expect(bells.count == 2)
    // Both bells should be at session end
    let pranayamaEnd = Double(ProgramSchedule.actualPranayamaSeconds(week: 3, phaseDuration: 4))
    let config = ProgramSchedule.config(for: 3)
    let focusSeconds = config.focusSeconds + ProgramSchedule.leftoverSeconds(week: 3, phaseDuration: 4)
    let sessionEnd = pranayamaEnd + 3.0 + Double(focusSeconds)
    #expect(bells[0].offsetSeconds == sessionEnd)
    #expect(bells[1].offsetSeconds == sessionEnd + 1.5)
}
