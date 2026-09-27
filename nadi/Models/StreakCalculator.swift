import Foundation

/// Shared streak calculation logic used by HomeView and StatsView.
enum StreakCalculator {
    /// Current consecutive-day streak, allowing today to be unpracticed.
    static func currentStreak(completedDates: Set<String>, now: Date = Date()) -> Int {
        let formatter = DateFormatting.localDateFormatter

        var streak = 0
        var checkDate = now

        // If today hasn't been practiced yet, start checking from yesterday
        let todayStr = formatter.string(from: checkDate)
        if !completedDates.contains(todayStr) {
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        while true {
            let dateStr = formatter.string(from: checkDate)
            if completedDates.contains(dateStr) {
                streak += 1
                guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    /// Longest consecutive-day streak across all time.
    static func longestStreak(completedDates: Set<String>) -> Int {
        guard !completedDates.isEmpty else { return 0 }
        let sorted = completedDates.sorted()
        var maxStreak = 1
        var current = 1

        let formatter = DateFormatting.localDateFormatter

        for i in 1..<sorted.count {
            guard let d1 = formatter.date(from: sorted[i - 1]),
                  let d2 = formatter.date(from: sorted[i]) else { continue }
            let diff = Calendar.current.dateComponents([.day], from: d1, to: d2).day ?? 0
            if diff == 1 {
                current += 1
                maxStreak = max(maxStreak, current)
            } else {
                current = 1
            }
        }
        return maxStreak
    }

    /// Number of consecutive days since a given start date.
    /// Used for week auto-advance (7 consecutive days = advance).
    ///
    /// Note: Returns 0 if ANY day between `startDate` and yesterday has a gap.
    /// This means a single missed day resets the counter entirely — intentional,
    /// since week advancement requires 7 *consecutive* days of practice.
    static func consecutiveDaysSince(startDate: String, completedDates: Set<String>, now: Date = Date()) -> Int {
        let formatter = DateFormatting.localDateFormatter

        guard let start = formatter.date(from: startDate) else { return 0 }
        var count = 0
        var checkDate = start

        while true {
            let dateStr = formatter.string(from: checkDate)
            if completedDates.contains(dateStr) {
                count += 1
                guard let next = Calendar.current.date(byAdding: .day, value: 1, to: checkDate) else { break }
                checkDate = next
            } else {
                // If we're checking today or the future, stop (it hasn't happened yet)
                if checkDate >= Calendar.current.startOfDay(for: now) {
                    break
                }
                // Gap found before today — streak is broken
                return 0
            }
        }
        return count
    }

    /// Practice days in the last seven days (today and the six before it) that fall on or after
    /// `startDate`. Used for week auto-advance: six of seven matches the course's own baseline
    /// ("every morning except Sunday"), and the window slides, so one missed day costs a day,
    /// not the week. (`consecutiveDaysSince` could never recover once a gap sat between the week's
    /// start date and today — after one missed day the week never advanced again.)
    static func practiceDaysInLastWeek(startDate: String, completedDates: Set<String>, now: Date = Date()) -> Int {
        let formatter = DateFormatting.localDateFormatter
        guard formatter.date(from: startDate) != nil else { return 0 }
        var count = 0
        for offset in 0..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: now) else { continue }
            let dayStr = formatter.string(from: day)
            // "yyyy-MM-dd" strings compare chronologically
            if dayStr >= startDate, completedDates.contains(dayStr) {
                count += 1
            }
        }
        return count
    }
}
