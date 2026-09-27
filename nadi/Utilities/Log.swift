import OSLog

extension Logger {
    static let audio = Logger(subsystem: Bundle.main.bundleIdentifier ?? "nadi", category: "audio")
    static let session = Logger(subsystem: Bundle.main.bundleIdentifier ?? "nadi", category: "session")
    static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "nadi", category: "app")
}
