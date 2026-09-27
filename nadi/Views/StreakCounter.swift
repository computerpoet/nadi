import SwiftUI

struct StreakCounter: View {
    let current: Int
    let longest: Int
    let totalSessions: Int
    let totalMinutes: Int

    var body: some View {
        HStack(spacing: 20) {
            stat(value: current, label: "Current\nStreak")
            divider
            stat(value: longest, label: "Longest\nStreak")
            divider
            stat(value: totalSessions, label: "Total\nSessions")
            divider
            stat(value: totalMinutes, label: "Total\nMinutes")
        }
        .padding(.vertical, 12)
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 28, weight: .light, design: .monospaced))
                .foregroundStyle(NadiColor.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(NadiColor.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(NadiColor.textMuted)
            .frame(width: 1, height: 40)
    }
}
