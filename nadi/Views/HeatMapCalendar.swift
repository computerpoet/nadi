import SwiftUI

struct HeatMapCalendar: View {
    let sessions: [MeditationSession]
    let weeks: Int // how many weeks to show

    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 2
    private let daysOfWeek = 7

    var body: some View {
        let columns = weekColumns
        let byDate = sessionsByDate
        let today = todayString()

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(columns, id: \.self) { weekDates in
                    VStack(spacing: cellSpacing) {
                        ForEach(weekDates, id: \.self) { date in
                            cell(for: date, byDate: byDate, today: today)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Grid Construction

    /// Returns an array of weeks, each containing 7 date strings (Mon-Sun).
    private var weekColumns: [[String]] {
        let calendar = Calendar.current
        let today = Date()
        var columns: [[String]] = []

        // Work backwards from this week
        for weekOffset in stride(from: weeks - 1, through: 0, by: -1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: startOfWeek(today)) else { continue }
            var week: [String] = []
            for day in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: day, to: weekStart) {
                    week.append(DateFormatting.localDateString(from: date))
                }
            }
            columns.append(week)
        }
        return columns
    }

    private func startOfWeek(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    // MARK: - Cell

    private func cell(for dateString: String, byDate: [String: Int], today: String) -> some View {
        let minutes = byDate[dateString] ?? 0
        let isToday = dateString == today

        return RoundedRectangle(cornerRadius: 2)
            .fill(colorForMinutes(minutes))
            .frame(width: cellSize, height: cellSize)
            .overlay(
                isToday
                    ? RoundedRectangle(cornerRadius: 2).stroke(NadiColor.textSecondary, lineWidth: 1)
                    : nil
            )
            .accessibilityLabel(minutes > 0 ? "\(dateString): \(minutes) minutes" : dateString)
            .accessibilityValue(isToday ? "Today" : "")
    }

    // MARK: - Data

    private var sessionsByDate: [String: Int] {
        var map: [String: Int] = [:]
        for s in sessions where s.completed {
            map[s.localDate, default: 0] += s.totalDuration / 60
        }
        return map
    }

    private func colorForMinutes(_ minutes: Int) -> Color {
        switch minutes {
        case 0:       Color(red: 0.086, green: 0.106, blue: 0.133) // #161B22
        case 1..<15:  Color(red: 0.055, green: 0.267, blue: 0.161) // #0E4429
        case 15..<40: Color(red: 0.0, green: 0.427, blue: 0.196)   // #006D32
        case 40..<60: Color(red: 0.149, green: 0.651, blue: 0.255) // #26A641
        default:      Color(red: 0.224, green: 0.827, blue: 0.325) // #39D353
        }
    }

    private func todayString() -> String {
        DateFormatting.todayString()
    }
}
