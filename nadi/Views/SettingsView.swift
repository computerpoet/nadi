import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MeditationSession.startTime, order: .reverse) private var sessions: [MeditationSession]
    @State private var showClearConfirmation = false
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var exportURL: URL?
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            ZStack {
                NadiColor.background
                    .ignoresSafeArea()

                List {
                    // Program
                    Section("Program") {
                        Picker("Week", selection: $settings.currentWeek) {
                            ForEach(1...6, id: \.self) { week in
                                let config = ProgramSchedule.config(for: week)
                                if config.hasFocusPhase {
                                    Text("Week \(week) — \(config.pranayamaMinutes)m + \(config.focusMinutes)m")
                                        .tag(week)
                                } else {
                                    Text("Week \(week) — \(config.pranayamaMinutes)m pranayama")
                                        .tag(week)
                                }
                            }
                        }
                        .onChange(of: settings.currentWeek) {
                            settings.weekStartDate = todayString()
                        }
                    }

                    // Breathing
                    Section("Breathing") {
                        Stepper(
                            "Phase duration: \(settings.phaseDuration)s",
                            value: $settings.phaseDuration,
                            in: 2...16
                        )

                        Picker("Tick mode", selection: $settings.tickMode) {
                            ForEach(TickMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                    }

                    // Session
                    Section("Session") {
                        Stepper(
                            "Countdown: \(settings.countdownSeconds)s",
                            value: $settings.countdownSeconds,
                            in: 3...10
                        )

                        Picker("Focus timer", selection: $settings.timerDirection) {
                            ForEach(TimerDirection.allCases) { dir in
                                Text(dir.label).tag(dir)
                            }
                        }
                    }

                    // Data
                    Section("Data") {
                        Button("Export Session History") {
                            exportSessions()
                        }

                        Button("Import Session History") {
                            showImportPicker = true
                        }

                        Button("Clear All Data", role: .destructive) {
                            showClearConfirmation = true
                        }
                    }

                    // About
                    Section("About") {
                        Text("Meditation technique inspired by Jason Louv's Mastering Meditation at magick.me")
                            .font(.system(size: 13))
                            .foregroundStyle(NadiColor.textSecondary)

                        HStack {
                            Text("Version")
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundStyle(NadiColor.textTertiary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Clear all session data?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Clear All Data", role: .destructive) {
                    clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result,
                      let url = urls.first else { return }
                importSessions(from: url)
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Export

    private func exportSessions() {
        let dtos = sessions.map { SessionDTO(from: $0) }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(dtos)
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("nadi-sessions.json")
            try data.write(to: tmpURL)
            exportURL = tmpURL
            showExportSheet = true
        } catch {
            alertTitle = "Export Failed"
            alertMessage = "Could not create export file.\n\n\(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: - Import

    private func importSessions(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            alertTitle = "Import Failed"
            alertMessage = "Cannot access the selected file. Try copying it to your device first."
            showAlert = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            alertTitle = "Import Failed"
            alertMessage = "Could not read the file.\n\n\(error.localizedDescription)"
            showAlert = true
            return
        }

        let dtos: [SessionDTO]
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            dtos = try decoder.decode([SessionDTO].self, from: data)
        } catch {
            alertTitle = "Import Failed"
            alertMessage = "The file is not valid JSON or has an unexpected format.\n\n\(error.localizedDescription)"
            showAlert = true
            return
        }

        var imported = 0
        var skipped = 0

        for dto in dtos {
            guard dto.isValid() else {
                skipped += 1
                continue
            }

            // Skip duplicates (same startTime)
            guard !sessions.contains(where: { $0.startTime == dto.startTime }) else { continue }

            modelContext.insert(dto.toSession())
            imported += 1
        }

        do {
            try modelContext.save()
            alertTitle = "Import Complete"
            alertMessage = skipped > 0
                ? "Imported \(imported) session(s). \(skipped) skipped (invalid or malformed)."
                : "Imported \(imported) session(s)."
            showAlert = true
        } catch {
            alertTitle = "Import Failed"
            alertMessage = "Sessions could not be saved.\n\n\(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: - Clear

    private func clearAllData() {
        do {
            try modelContext.delete(model: MeditationSession.self)
            try modelContext.delete(model: InProgressSession.self)
            try modelContext.save()
        } catch {
            alertTitle = "Clear Failed"
            alertMessage = "Could not delete session data.\n\n\(error.localizedDescription)"
            showAlert = true
        }
    }

    private func todayString() -> String {
        DateFormatting.todayString()
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
