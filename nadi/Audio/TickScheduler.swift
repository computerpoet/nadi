import AVFoundation
import OSLog

/// Represents a single audio event in the session timeline.
struct TickEvent: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case tick
        case stressed
        case bell
    }

    let kind: Kind
    /// Offset in seconds from session start (t=0, after countdown).
    let offsetSeconds: Double
}

/// Pre-computes all tick events for a session and schedules them all upfront
/// via AVAudioEngine's sample-accurate scheduling.
///
/// All events are scheduled in one pass (max ~1200 events for a 20-minute session).
/// Each `scheduleBuffer` enqueues a pointer to the shared buffer — negligible memory.
/// This eliminates the need for a background refill timer, which was unreliable
/// when iOS suspended Swift concurrency tasks in background.
///
/// Scheduling uses **player-relative time** following Apple's HelloMetronome pattern:
/// - Player time 0 = when play() is called
/// - All AVAudioTime values are relative to player start, NOT absolute render time
/// - Engine is started first, events scheduled, then players started
/// Stored in SessionState via `nonisolated(unsafe)`.
final class TickScheduler {
    private let engine: AudioEngine
    private var events: [TickEvent] = []
    private var nextEventIndex = 0

    /// Tracks how far into the session player time 0 corresponds to.
    /// For initial start: 0.0 (player time 0 = session time 0)
    /// For restart after pause: the elapsed seconds at restart time
    private var playerTimeOffset: Double = 0

    init(engine: AudioEngine) {
        self.engine = engine
    }

    // MARK: - Event Computation

    /// Pre-compute all tick/bell events for the entire session (static, pure function).
    static func computeEventTimeline(
        weekConfig: ProgramSchedule.WeekConfig,
        phaseDuration: Int,
        tickMode: TickMode,
        actualPranayamaSeconds: Int,
        actualFocusSeconds: Int
    ) -> [TickEvent] {
        precondition(phaseDuration >= 1)
        var events: [TickEvent] = []

        let totalCycles = actualPranayamaSeconds / (3 * phaseDuration)
        for cycle in 0..<totalCycles {
            for phaseIndex in 0..<3 {
                for second in 0..<phaseDuration {
                    let offset = Double(cycle * 3 * phaseDuration + phaseIndex * phaseDuration + second)
                    if second == 0 {
                        events.append(TickEvent(kind: .stressed, offsetSeconds: offset))
                    } else if tickMode == .all {
                        events.append(TickEvent(kind: .tick, offsetSeconds: offset))
                    }
                }
            }
        }

        let pranayamaEnd = Double(actualPranayamaSeconds)

        if weekConfig.hasFocusPhase {
            let sessionEnd = pranayamaEnd + 3.0 + Double(actualFocusSeconds)
            events.append(TickEvent(kind: .bell, offsetSeconds: sessionEnd))
            events.append(TickEvent(kind: .bell, offsetSeconds: sessionEnd + 1.5))
        } else {
            events.append(TickEvent(kind: .bell, offsetSeconds: pranayamaEnd))
            events.append(TickEvent(kind: .bell, offsetSeconds: pranayamaEnd + 1.5))
        }

        events.sort { $0.offsetSeconds < $1.offsetSeconds }
        return events
    }

    /// Pre-compute all tick/bell events for the entire session.
    func computeEvents(
        weekConfig: ProgramSchedule.WeekConfig,
        phaseDuration: Int,
        tickMode: TickMode,
        actualPranayamaSeconds: Int,
        actualFocusSeconds: Int
    ) {
        events = Self.computeEventTimeline(
            weekConfig: weekConfig,
            phaseDuration: phaseDuration,
            tickMode: tickMode,
            actualPranayamaSeconds: actualPranayamaSeconds,
            actualFocusSeconds: actualFocusSeconds
        )
    }

    // MARK: - Scheduling

    /// Start scheduling from the beginning of the session.
    func start() {
        playerTimeOffset = 0
        nextEventIndex = 0
        scheduleAllRemaining()
        engine.startPlayers()
    }

    /// Restart scheduling from a new point (after pause/interruption/config change).
    func restart(elapsedSeconds: Double) {
        playerTimeOffset = elapsedSeconds
        nextEventIndex = events.firstIndex(where: { $0.offsetSeconds > elapsedSeconds }) ?? events.count
        scheduleAllRemaining()
        engine.startPlayers()
    }

    /// No-op after removing refill timer. Retained for call-site compatibility.
    func stop() {}

    /// Total session duration in seconds (time of last event + buffer).
    var totalDurationSeconds: Double {
        (events.last?.offsetSeconds ?? 0) + 2.0
    }

    // MARK: - Private

    /// Schedule all remaining events from `nextEventIndex` through end of array.
    private func scheduleAllRemaining() {
        let sampleRate = engine.bufferSampleRate
        guard sampleRate > 0 else { return }

        var scheduled = 0

        while nextEventIndex < events.count {
            let event = events[nextEventIndex]
            let playerSeconds = event.offsetSeconds - playerTimeOffset
            guard playerSeconds >= 0 else {
                nextEventIndex += 1
                continue
            }

            let playerFrame = AVAudioFramePosition(playerSeconds * sampleRate)
            let time = AVAudioTime(sampleTime: playerFrame, atRate: sampleRate)

            switch event.kind {
            case .tick: engine.scheduleTick(at: time)
            case .stressed: engine.scheduleStressedTick(at: time)
            case .bell: engine.scheduleBell(at: time)
            }

            nextEventIndex += 1
            scheduled += 1
        }
        if scheduled > 0 {
            Logger.audio.debug("Scheduled \(scheduled) events (playerOffset: \(String(format: "%.1f", self.playerTimeOffset))s)")
        }
    }
}
