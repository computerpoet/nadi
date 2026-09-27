import AVFoundation
import OSLog

enum AudioEngineError: Error {
    case missingAudioFile(String)
    case failedToReadAudioFile(String)
    case failedToCreateBuffer(String)
    case failedToLoadBuffer(String, Error)
}

/// Manages AVAudioEngine with 3 player nodes for sample-accurate tick playback.
/// Handles audio session, interruptions, and route changes.
///
/// Scheduling uses **player-relative time** (sample time 0 = when play() is called),
/// following Apple's HelloMetronome pattern.
///
/// ⚠️ NOT thread-safe. All methods must be called from the main actor.
/// Stored in SessionState via `nonisolated(unsafe)`.
final class AudioEngine {
    private let engine = AVAudioEngine()
    private let tickPlayer = AVAudioPlayerNode()
    private let stressedPlayer = AVAudioPlayerNode()
    private let bellPlayer = AVAudioPlayerNode()

    // Set by setup(). Callers must call setup() before scheduling.
    private(set) var tickBuffer: AVAudioPCMBuffer?
    private(set) var stressedBuffer: AVAudioPCMBuffer?
    private(set) var bellBuffer: AVAudioPCMBuffer?

    /// The buffer sample rate, used for all AVAudioTime calculations.
    /// Set after setup() loads buffers.
    private(set) var bufferSampleRate: Double = 0

    var isRunning: Bool { engine.isRunning }

    init() {
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    /// Configure AVAudioSession for background playback through silent switch.
    /// Uses `.mixWithOthers` so ticks play alongside user's music without volume ducking.
    /// Avoids `.duckOthers` which causes iOS to oscillate ducking state during silence
    /// gaps between ticks, triggering spurious AVAudioEngineConfigurationChange notifications.
    func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    /// Deactivate audio session and notify other apps they can resume full volume.
    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Logger.audio.warning("Failed to deactivate audio session: \(error)")
        }
    }

    /// Attach player nodes to engine, connect to mixer, load sound buffers.
    ///
    /// Audio files are pre-converted to 2ch 48kHz to match hardware output.
    /// Connection uses the buffer's format so scheduleBuffer format matches.
    func setup() throws {
        // Load buffers first to get their format
        let tick = try loadBuffer(named: "tick", ext: "wav")
        let stressed = try loadBuffer(named: "tick-stressed", ext: "wav")
        let bell = try loadBuffer(named: "bell", ext: "wav")
        tickBuffer = tick
        stressedBuffer = stressed
        bellBuffer = bell

        let format = tick.format
        bufferSampleRate = format.sampleRate

        // Attach player nodes
        engine.attach(tickPlayer)
        engine.attach(stressedPlayer)
        engine.attach(bellPlayer)

        // Connect using the buffer's format.
        // scheduleBuffer requires buffer.format == connection format.
        let mainMixer = engine.mainMixerNode
        engine.connect(tickPlayer, to: mainMixer, format: format)
        engine.connect(stressedPlayer, to: mainMixer, format: format)
        engine.connect(bellPlayer, to: mainMixer, format: format)

        engine.prepare()
    }

    /// Start the engine only. Players are started via startPlayers()
    /// after the first events have been scheduled.
    func startEngine() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }

    /// Start (or restart) the player nodes. Call after scheduling first events
    /// so that player time 0 aligns with the first scheduled buffer.
    func startPlayers() {
        tickPlayer.play()
        stressedPlayer.play()
        bellPlayer.play()
    }

    func stop() {
        tickPlayer.stop()
        stressedPlayer.stop()
        bellPlayer.stop()
        engine.stop()
    }

    func pause() {
        tickPlayer.stop()
        stressedPlayer.stop()
        bellPlayer.stop()
        engine.pause()
    }

    // MARK: - Scheduling (player-relative time)

    func scheduleTick(at time: AVAudioTime) {
        guard let tickBuffer else { return }
        tickPlayer.scheduleBuffer(tickBuffer, at: time, options: [], completionHandler: nil)
    }

    func scheduleStressedTick(at time: AVAudioTime) {
        guard let stressedBuffer else { return }
        stressedPlayer.scheduleBuffer(stressedBuffer, at: time, options: [], completionHandler: nil)
    }

    func scheduleBell(at time: AVAudioTime) {
        guard let bellBuffer else { return }
        bellPlayer.scheduleBuffer(bellBuffer, at: time, options: [], completionHandler: nil)
    }

    // MARK: - Buffer Loading

    private func loadBuffer(named name: String, ext: String) throws -> AVAudioPCMBuffer {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw AudioEngineError.missingAudioFile("\(name).\(ext)")
        }

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw AudioEngineError.failedToReadAudioFile("\(name).\(ext)")
        }

        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioEngineError.failedToCreateBuffer("\(name).\(ext)")
        }

        do {
            try file.read(into: buffer)
        } catch {
            throw AudioEngineError.failedToLoadBuffer("\(name).\(ext)", error)
        }

        return buffer
    }

    // MARK: - Interruption Handling

    /// Called when audio resumes after interruption. Override point for rescheduling.
    /// Must be a @MainActor closure since SessionState is @MainActor.
    var onInterruptionEnded: (@MainActor @Sendable () -> Void)?
    /// Called when audio is interrupted (phone call, Siri, etc.).
    /// Must be a @MainActor closure since SessionState is @MainActor.
    var onInterruptionBegan: (@MainActor @Sendable () -> Void)?
    /// Called when media services are reset (coreaudiod crash). Session must be aborted.
    var onMediaServicesReset: (@MainActor @Sendable () -> Void)?
    /// Called after audio engine configuration change (Bluetooth connect, hardware change).
    /// Callers must reschedule events and restart players — reconnectNodes() flushes all buffers.
    var onConfigurationChange: (@MainActor @Sendable () -> Void)?

    /// Tracks whether we're in an interruption to coordinate with config changes.
    private var isSuspended = false
    private var isConfigChangePending = false

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }

        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMediaServicesReset()
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            isSuspended = true
            if let callback = onInterruptionBegan {
                Task { @MainActor in callback() }
            }
        case .ended:
            isSuspended = false

            // Check if iOS says we should resume. If not, stay paused — user can tap to resume.
            let shouldResume: Bool
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
            } else {
                shouldResume = false
            }
            guard shouldResume else { return }

            // Reconfigure audio session (another app may have changed category)
            do {
                try configureAudioSession()
            } catch {
                Logger.audio.error("Failed to reconfigure audio session after interruption: \(error)")
            }
            if isConfigChangePending {
                isConfigChangePending = false
                reconnectNodes()
            }
            if let callback = onInterruptionEnded {
                Task { @MainActor in callback() }
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        if reason == .oldDeviceUnavailable {
            // Headphones unplugged — iOS pauses audio. Pause the session.
            if let callback = onInterruptionBegan {
                Task { @MainActor in callback() }
            }
        }
    }

    /// Hardware sample rate or channel count changed (Bluetooth connect, external interface).
    /// Engine stops itself; connections may be stale.
    private func handleConfigurationChange() {
        if isSuspended {
            // Defer reconnection until interruption ends
            isConfigChangePending = true
        } else {
            reconnectNodes()
            do {
                try engine.start()
            } catch {
                Logger.audio.error("Failed to restart engine after config change: \(error)")
            }
            // Notify SessionState to reschedule events and restart players.
            // reconnectNodes() flushed all scheduled buffers.
            if let callback = onConfigurationChange {
                Task { @MainActor in callback() }
            }
        }
    }

    /// coreaudiod crashed — everything is destroyed. Must rebuild from scratch.
    private func handleMediaServicesReset() {
        if let callback = onMediaServicesReset {
            Task { @MainActor in callback() }
        }
    }

    /// Re-wire player nodes to mixer with current buffer format.
    private func reconnectNodes() {
        guard let format = tickBuffer?.format else { return }
        let mainMixer = engine.mainMixerNode
        engine.disconnectNodeOutput(tickPlayer)
        engine.disconnectNodeOutput(stressedPlayer)
        engine.disconnectNodeOutput(bellPlayer)
        engine.connect(tickPlayer, to: mainMixer, format: format)
        engine.connect(stressedPlayer, to: mainMixer, format: format)
        engine.connect(bellPlayer, to: mainMixer, format: format)
    }
}
