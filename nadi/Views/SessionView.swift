import CoreHaptics
import OSLog
import SwiftData
import SwiftUI

struct SessionView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var session = SessionState()
    @State private var showCloseEyesPrompt = false
    @State private var closeEyesOpacity: Double = 0
    @State private var showEndButton = false
    @State private var focusPeekTimer: Timer?
    @State private var showFocusTime = false
    @State private var hapticEngine: CHHapticEngine?
    @State private var closeEyesTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.2), value: breathPhase)

            VStack(spacing: 0) {
                // End session — always present but very muted, brightens on tap
                HStack {
                    Spacer()
                    Button("End") {
                        session.requestCancel()
                    }
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(NadiColor.textMuted)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("End session")
                    .padding(.trailing, 8)
                }

                Spacer()

                sessionContent

                Spacer()
            }

            // "Close your eyes" prompt — appears after first 2 breath cycles
            if showCloseEyesPrompt {
                Text("Close your eyes")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(NadiColor.textPrimary.opacity(closeEyesOpacity))
            }

            // Pause overlay
            if session.isPaused {
                NadiColor.background.opacity(0.85)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Paused")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(NadiColor.textSecondary)
                    Text("Tap to resume")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(NadiColor.textTertiary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        .alert("End Session?", isPresented: $session.showCancelConfirmation) {
            Button("Continue", role: .cancel) {}
            Button("End", role: .destructive) {
                session.confirmCancel()
            }
        } message: {
            Text("Sessions less than 50% complete won't count toward your streak.")
        }
        .alert("Error", isPresented: Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                session.reset()
                dismiss()
            }
        } message: {
            Text(session.errorMessage ?? "An unknown error occurred.")
        }
        .onAppear {
            session.configure(settings: settings, modelContext: modelContext)
            session.start()
            prepareHaptics()
        }
        .onChange(of: breathPhase) { oldPhase, newPhase in
            // Fire haptic on phase change (pairs with stressed tick audio)
            if let newPhase, oldPhase != newPhase {
                firePhaseHaptic()
            }

            // Show "Close your eyes" after the 2nd cycle starts
            if case .pranayama(_, _, let cycle, _) = session.phase, cycle >= 2, !showCloseEyesPrompt {
                triggerCloseEyesPrompt()
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Content

    @ViewBuilder
    private var sessionContent: some View {
        switch session.phase {
        case .idle:
            EmptyView()

        case .countdown(let remaining):
            Text("\(remaining)")
                .font(.system(size: 96, weight: .ultraLight, design: .monospaced))
                .foregroundStyle(NadiColor.textPrimary.opacity(0.6))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: remaining)

        case .pranayama(let breathPhase, _, _, _):
            // Phase label only — no countdown, no cycle counter
            Text(breathPhase.rawValue)
                .font(.system(size: 28, weight: .light, design: .monospaced))
                .foregroundStyle(NadiColor.textPrimary.opacity(0.7))
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.5), value: breathPhase)

        case .transition:
            // Louv's dharana: attention held gently on the point between the eyebrows; bring it back when it wanders.
            VStack(spacing: 10) {
                Text("Silent meditation")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(NadiColor.textSecondary)
                Text("Attention on the point between the eyebrows")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(NadiColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

        case .focus(let elapsed, let total):
            // Near-black, tap to peek at time
            if showFocusTime {
                let display = settings.timerDirection == .countdown ? total - elapsed : elapsed
                Text(formatTime(display))
                    .font(.system(size: 48, weight: .ultraLight, design: .monospaced))
                    .foregroundStyle(NadiColor.textTertiary)
                    .transition(.opacity)
            }

        case .complete:
            SessionCompleteView(session: session) {
                cleanup()
                session.reset()
                dismiss()
            }
        }
    }

    // MARK: - Tap Handling

    private func handleTap() {
        switch session.handleTap() {
        case .togglePause:
            session.togglePause()
        case .peekFocusTime:
            peekFocusTime()
        case .none:
            break
        }
    }

    private func peekFocusTime() {
        focusPeekTimer?.invalidate()
        withAnimation(.easeIn(duration: 0.3)) {
            showFocusTime = true
        }
        focusPeekTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 1.0)) {
                    showFocusTime = false
                }
            }
        }
    }

    // MARK: - Close Eyes Prompt

    private func triggerCloseEyesPrompt() {
        showCloseEyesPrompt = true
        // Fade in
        withAnimation(.easeIn(duration: 1.5)) {
            closeEyesOpacity = 0.8
        }
        // Hold for 3 seconds, then fade out. Store handle for cancellation.
        closeEyesTask = Task {
            try? await Task.sleep(for: .seconds(4.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 2.0)) {
                closeEyesOpacity = 0
            }
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            showCloseEyesPrompt = false
        }
    }

    // MARK: - Haptics

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            engine.resetHandler = { [weak engine = engine] in
                try? engine?.start()
            }
            hapticEngine = engine
        } catch {
            Logger.session.warning("Haptic engine setup failed: \(error)")
        }
    }

    /// Subtle tap haptic on phase change — pairs with the stressed tick audio
    private func firePhaseHaptic() {
        guard let engine = hapticEngine else { return }
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3)
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [sharpness, intensity],
            relativeTime: 0
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Non-critical — silently continue
        }
    }

    private func cleanup() {
        hapticEngine?.stop()
        hapticEngine = nil
        closeEyesTask?.cancel()
        closeEyesTask = nil
        focusPeekTimer?.invalidate()
        focusPeekTimer = nil
    }

    // MARK: - Helpers

    private var breathPhase: BreathPhase? {
        if case .pranayama(let bp, _, _, _) = session.phase { bp } else { nil }
    }

    private var backgroundColor: Color {
        switch session.phase {
        case .focus:
            NadiColor.focusBackground
        default:
            switch breathPhase {
            case .inhale: NadiColor.phaseInhale
            case .hold:   NadiColor.phaseHold
            case .exhale: NadiColor.phaseExhale
            case nil:     NadiColor.background
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        DateFormatting.formatTime(seconds)
    }
}
