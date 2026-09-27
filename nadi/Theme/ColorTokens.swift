import SwiftUI

/// Central color tokens for the Nadi design system.
/// Deep blues + near-black backgrounds optimized for OLED and eyes-closed meditation.
enum NadiColor {
    // MARK: - Backgrounds

    /// Primary app background: #0A0A0F
    static let background = Color(red: 0.04, green: 0.04, blue: 0.06)

    /// Focus phase background — near black: #060608
    static let focusBackground = Color(red: 0.024, green: 0.024, blue: 0.032)

    // MARK: - Breath Phase Backgrounds (slow crossfade)

    /// Inhale: deep navy #1A2444
    static let phaseInhale = Color(red: 0.10, green: 0.14, blue: 0.27)

    /// Hold: deep purple #1A1440
    static let phaseHold = Color(red: 0.10, green: 0.08, blue: 0.25)

    /// Exhale: deep teal #0A1A2E
    static let phaseExhale = Color(red: 0.04, green: 0.10, blue: 0.18)

    // MARK: - Text

    /// Primary text: #E8E8EC
    static let textPrimary = Color(red: 0.91, green: 0.91, blue: 0.93)

    /// Secondary text: 50% opacity white
    static let textSecondary = Color.white.opacity(0.5)

    /// Tertiary text: 30% opacity white
    static let textTertiary = Color.white.opacity(0.3)

    /// Muted text: 20% opacity white
    static let textMuted = Color.white.opacity(0.2)

    // MARK: - Accent

    /// Primary accent blue: #4A7CFF
    static let accent = Color(red: 0.29, green: 0.49, blue: 1.0)

    /// Success green for completion indicators
    static let success = Color.green.opacity(0.7)
}
