import SwiftUI

/// Figtree, from the design. The font files go in App/Resources/Fonts and are listed under UIAppFonts in project.yml.
/// Until they are added, SwiftUI falls back to the system font, which keeps layout close.
enum AZFont {
    static func figtree(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Figtree", size: size, relativeTo: style).weight(weight)
    }

    static let display = figtree(64, .heavy, relativeTo: .largeTitle)  // "2,350"
    static let h1 = figtree(30, .heavy, relativeTo: .largeTitle)
    static let h2 = figtree(22, .heavy, relativeTo: .title2)
    static let title = figtree(17, .bold, relativeTo: .headline)
    static let body = figtree(15.5, .medium, relativeTo: .body)
    static let label = figtree(13.5, .semibold, relativeTo: .subheadline)
    static let caption = figtree(12.5, .semibold, relativeTo: .caption)
}

extension Font {
    /// Figtree at an exact size from the design, e.g. `.az(15, .bold)`.
    static func az(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        AZFont.figtree(size, weight)
    }
}
