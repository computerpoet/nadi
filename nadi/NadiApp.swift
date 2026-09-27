import OSLog
import SwiftData
import SwiftUI

@main
struct NadiApp: App {
    let modelContainer: ModelContainer
    @State private var settings = AppSettings()
    @State private var recoveryMessage: String?

    init() {
        do {
            modelContainer = try ModelContainer(
                for: MeditationSession.self, InProgressSession.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.onboardingComplete {
                    ContentView()
                        .environment(settings)
                } else {
                    OnboardingView()
                        .environment(settings)
                }
            }
            .task {
                recoverInterruptedSessions()
            }
            .alert("Session Recovered", isPresented: Binding(
                get: { recoveryMessage != nil },
                set: { if !$0 { recoveryMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(recoveryMessage ?? "")
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }

    private func recoverInterruptedSessions() {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<InProgressSession>()

        guard let inProgressSessions = try? context.fetch(descriptor),
              !inProgressSessions.isEmpty else { return }

        var recovered = 0
        for record in inProgressSessions {
            if record.isCompleted {
                let localDate = DateFormatting.localDateString(from: record.startTime)

                let session = MeditationSession(
                    localDate: localDate,
                    startTime: record.startTime,
                    totalDuration: record.elapsedSeconds,
                    plannedDuration: record.plannedDuration,
                    pranayamaDuration: min(record.elapsedSeconds,
                        ProgramSchedule.actualPranayamaSeconds(
                            week: record.weekNumber,
                            phaseDuration: record.phaseDuration
                        )),
                    focusDuration: max(0, record.elapsedSeconds -
                        ProgramSchedule.actualPranayamaSeconds(
                            week: record.weekNumber,
                            phaseDuration: record.phaseDuration
                        )),
                    weekNumber: record.weekNumber,
                    phaseDuration: record.phaseDuration
                )
                context.insert(session)
                recovered += 1
            }
            context.delete(record)
        }

        do {
            try context.save()
        } catch {
            Logger.app.error("Failed to save recovered sessions: \(error)")
            recoveryMessage = "A previous session could not be recovered.\n\nCheck available storage."
            return
        }

        if recovered > 0 {
            recoveryMessage = "Your previous session was interrupted but has been saved."
        }
    }
}

struct ContentView: View {
    var body: some View {
        HomeView()
    }
}
