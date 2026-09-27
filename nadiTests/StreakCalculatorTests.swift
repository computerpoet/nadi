import Testing
@testable import nadi
import Foundation

// MARK: - Helpers

private let calendar = Calendar.current

private func dateString(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = .current
    return f.string(from: date)
}

private func daysAgo(_ n: Int, from ref: Date) -> String {
    dateString(calendar.date(byAdding: .day, value: -n, to: ref)!)
}

/// Fixed reference date for deterministic tests.
private let now = Date(timeIntervalSince1970: 1_738_972_800) // 2025-02-08 00:00:00 UTC

// MARK: - currentStreak

@Test func currentStreakEmpty() {
    #expect(StreakCalculator.currentStreak(completedDates: [], now: now) == 0)
}

@Test func currentStreakTodayOnly() {
    let dates: Set<String> = [daysAgo(0, from: now)]
    #expect(StreakCalculator.currentStreak(completedDates: dates, now: now) == 1)
}

@Test func currentStreakYesterdayOnly() {
    let dates: Set<String> = [daysAgo(1, from: now)]
    #expect(StreakCalculator.currentStreak(completedDates: dates, now: now) == 1)
}

@Test func currentStreakConsecutive() {
    let dates: Set<String> = [daysAgo(0, from: now), daysAgo(1, from: now), daysAgo(2, from: now)]
    #expect(StreakCalculator.currentStreak(completedDates: dates, now: now) == 3)
}

@Test func currentStreakGapBreaks() {
    // today, yesterday, skip day 2, day 3
    let dates: Set<String> = [daysAgo(0, from: now), daysAgo(1, from: now), daysAgo(3, from: now)]
    #expect(StreakCalculator.currentStreak(completedDates: dates, now: now) == 2)
}

@Test func currentStreakStartsFromYesterdayWhenTodayMissing() {
    let dates: Set<String> = [daysAgo(1, from: now), daysAgo(2, from: now), daysAgo(3, from: now)]
    #expect(StreakCalculator.currentStreak(completedDates: dates, now: now) == 3)
}

@Test func currentStreakZeroWhenNeitherTodayNorYesterday() {
    let dates: Set<String> = [daysAgo(2, from: now), daysAgo(3, from: now)]
    #expect(StreakCalculator.currentStreak(completedDates: dates, now: now) == 0)
}

// MARK: - longestStreak

@Test func longestStreakEmpty() {
    #expect(StreakCalculator.longestStreak(completedDates: []) == 0)
}

@Test func longestStreakSingleDay() {
    #expect(StreakCalculator.longestStreak(completedDates: ["2025-01-15"]) == 1)
}

@Test func longestStreakContiguous() {
    let dates: Set<String> = ["2025-01-01", "2025-01-02", "2025-01-03", "2025-01-04"]
    #expect(StreakCalculator.longestStreak(completedDates: dates) == 4)
}

@Test func longestStreakWithGap() {
    let dates: Set<String> = [
        "2025-01-01", "2025-01-02", "2025-01-03",
        "2025-01-10", "2025-01-11",
    ]
    #expect(StreakCalculator.longestStreak(completedDates: dates) == 3)
}

// MARK: - consecutiveDaysSince

@Test func consecutiveDaysSinceEmpty() {
    #expect(StreakCalculator.consecutiveDaysSince(startDate: "2025-01-01", completedDates: [], now: now) == 0)
}

@Test func consecutiveDaysSinceInvalidDate() {
    #expect(StreakCalculator.consecutiveDaysSince(startDate: "bad", completedDates: ["2025-01-01"], now: now) == 0)
}

@Test func consecutiveDaysSinceFullStreak() {
    var dates = Set<String>()
    for i in 0...5 {
        dates.insert(daysAgo(i, from: now))
    }
    let start = daysAgo(5, from: now)
    #expect(StreakCalculator.consecutiveDaysSince(startDate: start, completedDates: dates, now: now) == 6)
}

// MARK: - practiceDaysInLastWeek

@Test func practiceDaysInLastWeekEmpty() {
    #expect(StreakCalculator.practiceDaysInLastWeek(startDate: "2025-01-01", completedDates: [], now: now) == 0)
}

@Test func practiceDaysInLastWeekInvalidStart() {
    #expect(StreakCalculator.practiceDaysInLastWeek(startDate: "bad", completedDates: [daysAgo(0, from: now)], now: now) == 0)
}

@Test func practiceDaysInLastWeekCountsSixOfSevenWithOneGap() {
    // days 0,1,2,4,5,6 practised; day 3 missed
    let dates: Set<String> = [0, 1, 2, 4, 5, 6].reduce(into: []) { $0.insert(daysAgo($1, from: now)) }
    let start = daysAgo(6, from: now)
    #expect(StreakCalculator.practiceDaysInLastWeek(startDate: start, completedDates: dates, now: now) == 6)
}

@Test func practiceDaysInLastWeekIgnoresDaysBeforeStartAndOlderThanSeven() {
    // practised every day for two weeks, but the week only began 3 days ago
    let dates: Set<String> = (0...13).reduce(into: []) { $0.insert(daysAgo($1, from: now)) }
    let start = daysAgo(3, from: now)
    #expect(StreakCalculator.practiceDaysInLastWeek(startDate: start, completedDates: dates, now: now) == 4)
    // and never more than seven, whatever the history
    #expect(StreakCalculator.practiceDaysInLastWeek(startDate: "2000-01-01", completedDates: dates, now: now) == 7)
}
