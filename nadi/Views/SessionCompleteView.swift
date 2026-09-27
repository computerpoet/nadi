import SwiftUI

struct SessionCompleteView: View {
    let session: SessionState
    let onDone: () -> Void

    private var totalMinutes: Int {
        max(1, (Int(session.elapsedSeconds) - session.countdownSeconds) / 60)
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Text("Session Complete")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(NadiColor.textPrimary)

                Text("\(totalMinutes) min")
                    .font(.system(size: 56, weight: .ultraLight, design: .monospaced))
                    .foregroundStyle(NadiColor.textSecondary)
            }

            Spacer()

            Button(action: onDone) {
                Circle()
                    .fill(NadiColor.textPrimary)
                    .frame(width: 90, height: 90)
                    .overlay(
                        Text("Done")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(NadiColor.background)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done, return to home")
            .padding(.bottom, 60)
        }
    }
}
