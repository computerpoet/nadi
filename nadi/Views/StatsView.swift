import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \MeditationSession.startTime, order: .reverse) private var sessions: [MeditationSession]
    @Environment(\.dismiss) private var dismiss

    private var completedSessions: [MeditationSession] {
        sessions.filter(\.completed)
    }

    private var totalMinutes: Int {
        completedSessions.reduce(0) { $0 + $1.totalDuration } / 60
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NadiColor.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Streak counter
                        StreakCounter(
                            current: currentStreak,
                            longest: longestStreak,
                            totalSessions: completedSessions.count,
                            totalMinutes: totalMinutes
                        )

                        // 6-month heat map
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Activity")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(NadiColor.textSecondary)

                            HeatMapCalendar(sessions: sessions, weeks: 26)
                                .frame(height: 96)
                        }
                        .padding(.horizontal, 16)

                        // Recent sessions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Sessions")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(NadiColor.textSecondary)

                            ForEach(Array(sessions.prefix(20)), id: \.id) { session in
                                sessionRow(session)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sessionRow(_ session: MeditationSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.localDate)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(NadiColor.textPrimary)
                Text("Week \(session.weekNumber)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(NadiColor.textTertiary)
            }
            Spacer()
            Text(formatTime(session.totalDuration))
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(NadiColor.textSecondary)

            if session.completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(NadiColor.success)
                    .font(.system(size: 14))
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ seconds: Int) -> String {
        DateFormatting.formatTime(seconds)
    }

    // MARK: - Streaks

    private var completedDates: Set<String> {
        Set(completedSessions.map(\.localDate))
    }

    private var currentStreak: Int {
        StreakCalculator.currentStreak(completedDates: completedDates)
    }

    private var longestStreak: Int {
        StreakCalculator.longestStreak(completedDates: completedDates)
    }
}
