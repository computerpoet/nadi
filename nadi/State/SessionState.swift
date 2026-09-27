import Foundation
import OSLog
import SwiftData
import UIKit

enum SessionPhase: Equatable, Sendable {
    case idle
    case countdown(remaining: Int)
    case pranayama(breathPhase: BreathPhase, secondInPhase: Int, cycle: Int, totalCycles: Int)
    case transition // 3-second "Silent meditation" display
    case focus(elapsed: Int, total: Int)
    case complete
}

enum BreathPhase: String, Sendable {
    case inhale = "INHALE"
    case hold = "HOLD"
    case exhale = "EXHALE"
}

@MainActor
@Observable
final class SessionState {
    // MARK: - Public State

    var phase: SessionPhase = .idle
    var isPaused = false
    var elapsedSeconds: Double = 0
    var showCancelConfirmation = false
    var errorMessage: String?

    var isActive: Bool {
        switch phase {
        case .idle, .complete: false
        default: true
        }
    }

    // MARK: - Configuration (set before start)

    private(set) var weekNumber = 1
    private(set) var weekConfig = ProgramSchedule.config(for: 1)
    private(set) var phaseDuration = 4
    private(set) var tickMode: TickMode = .all
    private(set) var countdownSeconds = 5

    // MARK: - Internal

    private var audioEngine: AudioEngine?
    private var scheduler: TickScheduler?
    private var displayTask: Task<Void, Never>?
    private var sessionStartTime: Date?
    private var pauseStartTime: Date?
    private var totalPauseSeconds: Double = 0
    private var modelContext: ModelContext?
    private var inProgressSession: InProgressSession?
    private var lastHeartbeatTime: Date?

    // Actual durations (computed from program schedule + phase duration)
    private var actualPranayamaSeconds = 0
    private var actualFocusSeconds = 0
    private var plannedDuration = 0

    // MARK: - Lifecycle

    func configure(settings: AppSettings, modelContext: ModelContext) {
        self.modelContext = modelContext
        self.weekNumber = settings.currentWeek
        self.weekConfig = ProgramSchedule.config(for: settings.currentWeek)
        self.phaseDuration = settings.phaseDuration
        self.tickMode = settings.tickMode
        self.countdownSeconds = settings.countdownSeconds

        actualPranayamaSeconds = ProgramSchedule.actualPranayamaSeconds(
            week: settings.currentWeek, phaseDuration: phaseDuration
        )
        let leftover = ProgramSchedule.leftoverSeconds(
            week: settings.currentWeek, phaseDuration: phaseDuration
        )
        actualFocusSeconds = weekConfig.focusSeconds + leftover
        plannedDuration = weekConfig.totalSeconds
    }

    func start() {
        guard phase == .idle else { return }

        // Setup audio
        let engine = AudioEngine()
        do {
            try engine.configureAudioSession()
            try engine.setup()
        } catch let error as AudioEngineError {
            Logger.audio.error("Audio setup failed: \(error)")
            switch error {
            case .missingAudioFile(let file):
                errorMessage = "Missing audio file: \(file)\n\nThe app installation may be corrupted. Try reinstalling from the App Store."
            case .failedToReadAudioFile(let file):
                errorMessage = "Cannot read audio file: \(file)\n\nThe file may be corrupted. Try reinstalling the app."
            case .failedToCreateBuffer(let file):
                errorMessage = "Audio buffer creation failed for: \(file)\n\nYour device may be low on memory."
            case .failedToLoadBuffer(let file, let underlyingError):
                errorMessage = "Cannot load audio file: \(file)\n\nError: \(underlyingError.localizedDescription)"
            }
            return
        } catch let error as NSError where error.domain == NSOSStatusErrorDomain {
            Logger.audio.error("Audio session configuration failed: \(error)")
            errorMessage = "Cannot access audio system.\n\nAnother app may be using exclusive audio access. Close other audio apps and try again."
            return
        } catch {
            Logger.audio.error("Audio setup failed (unknown): \(error)")
            errorMessage = "Audio setup failed: \(error.localizedDescription)\n\nCheck Settings → \(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "This App") → Permissions."
            return
        }

        let sched = TickScheduler(engine: engine)
        sched.computeEvents(
            weekConfig: weekConfig,
            phaseDuration: phaseDuration,
            tickMode: tickMode,
            actualPranayamaSeconds: actualPranayamaSeconds,
            actualFocusSeconds: actualFocusSeconds
        )

        // Wire interruption and recovery handlers.
        // Callbacks are @MainActor closures — call handlers directly, no extra Task hop.
        engine.onInterruptionBegan = { [weak self] in
            self?.handleInterruptionBegan()
        }
        engine.onInterruptionEnded = { [weak self] in
            self?.handleInterruptionEnded()
        }
        engine.onMediaServicesReset = { [weak self] in
            self?.handleMediaServicesReset()
        }
        engine.onConfigurationChange = { [weak self] in
            self?.handleConfigurationChange()
        }

        self.audioEngine = engine
        self.scheduler = sched
        self.elapsedSeconds = 0
        self.totalPauseSeconds = 0
        self.isPaused = false
        self.lastHeartbeatTime = nil
        self.sessionStartTime = Date()

        UIApplication.shared.isIdleTimerDisabled = true

        createInProgressSession()

        phase = .countdown(remaining: countdownSeconds)
        startDisplayTimer()
    }

    func togglePause() {
        guard isActive else { return }

        if isPaused {
            // Resume
            if let pauseStart = pauseStartTime {
                totalPauseSeconds += Date().timeIntervalSince(pauseStart)
            }
            pauseStartTime = nil
            isPaused = false

            do {
                try audioEngine?.startEngine()
                scheduler?.restart(elapsedSeconds: sessionElapsed())
            } catch {
                Logger.session.error("Resume failed: \(error)")
            }
            startDisplayTimer()
        } else {
            // Pause
            isPaused = true
            pauseStartTime = Date()
            audioEngine?.pause()
            scheduler?.stop()
            cancelDisplayTimer()
        }
    }

    /// What the view should do in response to a screen tap.
    enum TapAction {
        case togglePause
        case peekFocusTime
        case none
    }

    func handleTap() -> TapAction {
        switch phase {
        case .focus:
            return isPaused ? .togglePause : .peekFocusTime
        case .countdown, .pranayama, .transition:
            return isActive ? .togglePause : .none
        case .idle, .complete:
            return .none
        }
    }

    func requestCancel() {
        showCancelConfirmation = true
    }

    func confirmCancel() {
        let elapsed = sessionElapsed()
        let meditationElapsed = max(0, elapsed - Double(countdownSeconds))
        let qualified = SessionQualification.isQualified(
            elapsedSeconds: Int(meditationElapsed),
            plannedDuration: plannedDuration
        )
        endSession(totalElapsed: meditationElapsed, qualified: qualified)
    }

    // MARK: - Display Timer

    /// Fires every ~0.1s to update UI phase. NOT used for audio — only visual.
    private func startDisplayTimer() {
        cancelDisplayTimer()
        displayTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.updatePhase()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func cancelDisplayTimer() {
        displayTask?.cancel()
        displayTask = nil
    }

    private func sessionElapsed() -> Double {
        PhaseCalculator.sessionElapsed(
            sessionStartTime: sessionStartTime,
            totalPauseSeconds: totalPauseSeconds,
            isPaused: isPaused,
            pauseStartTime: pauseStartTime
        )
    }

    private func updatePhase() {
        let elapsed = sessionElapsed()
        self.elapsedSeconds = elapsed

        // Heartbeat for InProgressSession — throttled to every 10s
        if lastHeartbeatTime.map({ Date().timeIntervalSince($0) >= 10 }) ?? true {
            lastHeartbeatTime = Date()
            updateInProgressTimestamp()
        }

        let (newPhase, command) = PhaseCalculator.computePhase(
            elapsed: elapsed,
            countdownSeconds: countdownSeconds,
            actualPranayamaSeconds: actualPranayamaSeconds,
            actualFocusSeconds: actualFocusSeconds,
            phaseDuration: phaseDuration,
            hasFocusPhase: weekConfig.hasFocusPhase
        )

        phase = newPhase

        switch command {
        case .none:
            break
        case .startAudio:
            startAudioIfNeeded()
        case .endSession(let totalElapsed, let qualified):
            endSession(totalElapsed: totalElapsed, qualified: qualified)
        }
    }

    private func startAudioIfNeeded() {
        // PhaseCalculator emits .startAudio every tick during pranayama.
        // Only act on the first one — once audio is running, skip.
        guard audioEngine?.isRunning != true else { return }
        do {
            try audioEngine?.startEngine()
            scheduler?.start()
        } catch {
            Logger.audio.error("Audio start failed: \(error)")
            errorMessage = "Failed to start audio playback: \(error.localizedDescription)\n\nCheck if another app is using audio exclusively."
            cancelDisplayTimer()
            phase = .idle
            audioEngine?.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Session End

    private func endSession(totalElapsed: Double, qualified: Bool) {
        cancelDisplayTimer()
        scheduler?.stop()
        audioEngine?.stop()
        audioEngine?.deactivateAudioSession()

        UIApplication.shared.isIdleTimerDisabled = false

        if let context = modelContext, let start = sessionStartTime {
            if qualified {
                let totalSeconds = Int(totalElapsed)
                let pranayamaActual = min(totalSeconds, actualPranayamaSeconds)
                let focusActual = max(0, totalSeconds - actualPranayamaSeconds)
                let localDate = DateFormatting.localDateString(from: start)

                let session = MeditationSession(
                    localDate: localDate,
                    startTime: start,
                    totalDuration: totalSeconds,
                    plannedDuration: plannedDuration,
                    pranayamaDuration: pranayamaActual,
                    focusDuration: focusActual,
                    weekNumber: weekNumber,
                    phaseDuration: phaseDuration
                )
                context.insert(session)
            }

            if let inProgress = inProgressSession {
                context.delete(inProgress)
                self.inProgressSession = nil
            }

            do {
                try context.save()
            } catch {
                Logger.session.error("Failed to save session: \(error)")
                errorMessage = "Your session could not be saved.\n\nCheck available storage and try again."
            }
        }

        phase = .complete
    }

    // MARK: - InProgressSession Management

    private func createInProgressSession() {
        guard let context = modelContext, let start = sessionStartTime else { return }
        let record = InProgressSession(
            startTime: start,
            plannedDuration: plannedDuration,
            weekNumber: weekNumber,
            phaseDuration: phaseDuration
        )
        context.insert(record)
        do {
            try context.save()
        } catch {
            Logger.session.error("Failed to save InProgressSession: \(error)")
        }
        self.inProgressSession = record
    }

    private func updateInProgressTimestamp() {
        inProgressSession?.lastActiveTimestamp = Date()
        do {
            try modelContext?.save()
        } catch {
            Logger.session.error("Failed to update InProgressSession timestamp: \(error)")
        }
    }

    // MARK: - Interruption Handling

    private func handleInterruptionBegan() {
        if !isPaused {
            isPaused = true
            pauseStartTime = Date()
            audioEngine?.pause()
            scheduler?.stop()
            cancelDisplayTimer()
        }
    }

    private func handleInterruptionEnded() {
        if isPaused {
            if let pauseStart = pauseStartTime {
                totalPauseSeconds += Date().timeIntervalSince(pauseStart)
            }
            pauseStartTime = nil
            isPaused = false
            do {
                try audioEngine?.startEngine()
                scheduler?.restart(elapsedSeconds: sessionElapsed())
                startDisplayTimer()
            } catch {
                Logger.audio.error("Audio resume after interruption failed: \(error)")
                errorMessage = "Audio could not resume after interruption.\n\nClose other audio apps and restart the session."
            }
        }
    }

    /// coreaudiod crashed — audio engine is destroyed. End session gracefully.
    private func handleMediaServicesReset() {
        let elapsed = sessionElapsed()
        let meditationElapsed = max(0, elapsed - Double(countdownSeconds))
        let qualified = SessionQualification.isQualified(
            elapsedSeconds: Int(meditationElapsed),
            plannedDuration: plannedDuration
        )
        errorMessage = "Audio system was reset by iOS.\n\nYour session has been saved."
        endSession(totalElapsed: meditationElapsed, qualified: qualified)
    }

    /// Audio engine configuration changed (Bluetooth, hardware). Engine already restarted
    /// by AudioEngine but all scheduled buffers were flushed. Reschedule and restart players.
    private func handleConfigurationChange() {
        guard isActive, !isPaused else { return }
        scheduler?.restart(elapsedSeconds: sessionElapsed())
    }

    func reset() {
        phase = .idle
        isPaused = false
        elapsedSeconds = 0
        cancelDisplayTimer()
        scheduler?.stop()
        audioEngine?.stop()
        audioEngine = nil
        scheduler = nil
    }
}
