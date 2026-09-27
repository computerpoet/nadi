/// Protocol for AudioEngine, enabling mock injection in tests.
protocol AudioEngineProtocol: AnyObject {
    var isRunning: Bool { get }

    func configureAudioSession() throws
    func setup() throws
    func startEngine() throws
    func startPlayers()
    func stop()
    func pause()
    func deactivateAudioSession()

    var onInterruptionBegan: (@MainActor @Sendable () -> Void)? { get set }
    var onInterruptionEnded: (@MainActor @Sendable () -> Void)? { get set }
    var onMediaServicesReset: (@MainActor @Sendable () -> Void)? { get set }
    var onConfigurationChange: (@MainActor @Sendable () -> Void)? { get set }
}

extension AudioEngine: AudioEngineProtocol {}
