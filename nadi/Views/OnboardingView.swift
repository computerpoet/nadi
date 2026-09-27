import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @State private var page = 0

    var body: some View {
        ZStack {
            NadiColor.background
                .ignoresSafeArea()

            TabView(selection: $page) {
                // Page 1 — Sigil + title
                VStack(spacing: 24) {
                    Spacer()

                    SigilView(strokeColor: NadiColor.accent)
                        .frame(width: 200, height: 200)

                    Text("Nadi Shodhana")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(NadiColor.textPrimary)

                    Text("Alternate Nostril Breathing")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(NadiColor.textSecondary)

                    Text("A simple, powerful pranayama technique. Close one nostril, inhale. Hold. Exhale through the other nostril. Repeat.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(NadiColor.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer()
                        .frame(maxHeight: .infinity)
                }
                .tag(0)

                // Page 2
                onboardingPage(
                    title: "6-Week Program",
                    subtitle: "Progressive Practice",
                    body: "Start with 10 minutes of breathing. Each week, the practice grows — adding silent meditation until you reach a full 60-minute session.",
                    page: 1
                )
                .tag(1)

                // Page 3
                VStack(spacing: 32) {
                    Spacer()

                    Text("Precision Timing")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(NadiColor.textPrimary)

                    Text("Metronome ticks guide your breath")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(NadiColor.textSecondary)

                    Text("Audio plays through silent mode and screen lock. Close your eyes and follow the ticks.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(NadiColor.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer()

                    Button {
                        settings.onboardingComplete = true
                    } label: {
                        VStack(spacing: 12) {
                            SigilView(strokeColor: NadiColor.accent)
                                .frame(width: 120, height: 120)
                            Text("Begin")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(NadiColor.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Begin, start using the app")
                    .padding(.bottom, 60)
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
    }

    private func onboardingPage(title: String, subtitle: String, body: String, page: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text(title)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(NadiColor.textPrimary)

            Text(subtitle)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(NadiColor.textSecondary)

            Text(body)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(NadiColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
                .frame(maxHeight: .infinity)
        }
    }
}
