import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MeditationSession.startTime, order: .reverse) private var sessions: [MeditationSession]
    @State private var showSession = false
    @State private var showStats = false
    @State private var showSettings = false

    private var weekConfig: ProgramSchedule.WeekConfig {
        ProgramSchedule.config(for: settings.currentWeek)
    }

    var body: some View {
        ZStack {
            NadiColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar — settings (left) + stats (right)
                HStack {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(NadiColor.textTertiary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Settings")
                    .padding(.leading, 8)

                    Spacer()

                    Button {
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(NadiColor.textTertiary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Statistics")
                    .padding(.trailing, 8)
                }

                Spacer()

                // Week context — muted, minimal
                weekContext

                // Begin button — the focal point
                beginButton
                    .padding(.top, 40)

                // Today status — subtle confirmation
                todayStatus
                    .padding(.top, 20)

                Spacer()
                    .frame(maxHeight: .infinity)
            }
        }
        .fullScreenCover(isPresented: $showSession) {
            SessionView()
        }
        .sheet(isPresented: $showStats) {
            StatsView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear { checkWeekAdvance() }
        .onChange(of: showSession) { _, isShowing in
            if !isShowing { checkWeekAdvance() }
        }
    }

    // MARK: - Week Auto-Advance

    private func checkWeekAdvance() {
        settings.checkWeekAdvance(completedDates: completedDates)
    }

    // MARK: - Week Context

    private var weekContext: some View {
        VStack(spacing: 6) {
            Text("Week \(settings.currentWeek)")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(NadiColor.textSecondary)

            let config = weekConfig
            if config.hasFocusPhase {
                Text("\(config.pranayamaMinutes) + \(config.focusMinutes) min")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(NadiColor.textTertiary)
            } else {
                Text("\(config.pranayamaMinutes) min")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(NadiColor.textTertiary)
            }
        }
    }

    // MARK: - Begin Button

    private var beginButton: some View {
        Button {
            showSession = true
        } label: {
            VStack(spacing: 20) {
                SigilView(strokeColor: NadiColor.accent)
                    .frame(width: 160, height: 160)

                Text("Begin")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(NadiColor.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Begin meditation session")
    }

    // MARK: - Today Status

    private var todayStatus: some View {
        Group {
            let todayTotal = todayMinutes
            if todayTotal > 0 {
                Text("\(todayTotal) min today")
                    .foregroundStyle(NadiColor.success)
            } else {
                Text("Not yet practiced")
                    .foregroundStyle(NadiColor.textMuted)
            }
        }
        .font(.system(size: 14, weight: .regular))
    }

    // MARK: - Computed Stats

    private var completedSessions: [MeditationSession] {
        sessions.filter(\.completed)
    }

    private var todayMinutes: Int {
        let today = todayString()
        let todaySessions = sessions.filter { $0.localDate == today && $0.completed }
        return todaySessions.reduce(0) { $0 + $1.totalDuration } / 60
    }

    private var completedDates: Set<String> {
        Set(completedSessions.map(\.localDate))
    }

    private func todayString() -> String {
        DateFormatting.todayString()
    }
}
