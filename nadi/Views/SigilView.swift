import SwiftUI

/// The Nadi sigil — rendered from the actual sigilengine.com source image.
/// Uses a template image from the asset catalog, tintable via `.foregroundStyle()`.
struct SigilView: View {
    var strokeColor: Color = NadiColor.accent

    var body: some View {
        Image("sigil")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(strokeColor)
    }
}
