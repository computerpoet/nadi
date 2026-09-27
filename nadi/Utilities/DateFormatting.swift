import Foundation

/// Shared date formatting utilities. DateFormatter is expensive to create —
/// these cached instances avoid recreating on every render cycle.
enum DateFormatting {
    /// Cached formatter for "yyyy-MM-dd" local date strings.
    /// Internal so StreakCalculator can reuse without allocating its own.
    static let localDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    /// Cached ISO8601 formatter for export/import.
    static let iso8601Formatter = ISO8601DateFormatter()

    /// Today's date as "yyyy-MM-dd" in the user's local timezone.
    static func todayString() -> String {
        localDateFormatter.string(from: Date())
    }

    /// Format a Date as "yyyy-MM-dd" in the user's local timezone.
    static func localDateString(from date: Date) -> String {
        localDateFormatter.string(from: date)
    }

    /// Format seconds as "m:ss" (e.g., "5:03", "12:00").
    static func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
