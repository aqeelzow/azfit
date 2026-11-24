import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Color tokens from the approved design (design/source/build.py, the `.scr` and `.scr.dark` CSS variables).
/// Use these names, never raw hex in views. Hard bans: no yellow, no circles (rings, dots, round crops).
enum AZColor {
    static let background = Color(light: 0xFFFFFF, dark: 0x111015)
    static let ink = Color(light: 0x1D1B22, dark: 0xF3F1F7)
    static let muted = Color(light: 0x7D7A86, dark: 0x9C98A6)
    static let faint = Color(light: 0xB3B0BB, dark: 0x67636F)
    /// Empty checkboxes, dashed guide lines, placeholder digits.
    static let ghost = Color(light: 0xC7C4CE, dark: 0x57535F)
    static let fill = Color(light: 0xF5F4F7, dark: 0x1E1C23)
    static let track = Color(light: 0xEEECF2, dark: 0x2A2730)
    static let hairline = Color(light: 0xECEAF0, dark: 0x24222A)
    static let card = Color(light: 0xFFFFFF, dark: 0x2C2934)
    /// The tab bar surface and its shadow.
    static let nav = Color(light: 0xFFFFFF, dark: 0x1A1820)
    static let navShadow = Color(light: 0x28145A, dark: 0x000000).opacity(0.1)
    /// The dark rest-timer bar in a live workout, and its secondary button.
    static let rest = Color(light: 0x1D1B22, dark: 0x211F27)
    static let rest2 = Color(light: 0x37343F, dark: 0x36333E)

    /// The purple. Buttons, active states, Div.
    static let accent = Color(light: 0x7C5CFF, dark: 0x8E72FF)
    static let accentSoft = Color(light: 0xA68FFF, dark: 0x5A44C4)

    /// Lavender tint = "Div touched this". Only use for Div's changes and notes.
    static let divTint = Color(light: 0xEFEAFF, dark: 0x251E40)
    static let divTintSoft = Color(light: 0xF5F2FF, dark: 0x1F1935)
    static let divInk = Color(light: 0x5B3FE0, dark: 0xC3B4FF)
    static let divMuted = Color(light: 0x615885, dark: 0xADA3D6)

    /// Primary button: near-black in light mode, near-white in dark mode.
    static let button = Color(light: 0x1D1B22, dark: 0xF3F1F7)
    static let buttonInk = Color(light: 0xFFFFFF, dark: 0x111015)

    /// Macro colors. Protein uses `accent`.
    static let carbs = Color(light: 0xB7A4FF, dark: 0x6F5BD6)
    static let fat = Color(light: 0xFF8FB1, dark: 0xFF9CBB)

    /// Muscle map: how many sets a muscle got, from none (0) to most (5).
    static let ramp: [Color] = [
        Color(light: 0xE9E7EE, dark: 0x2C2933), Color(light: 0xE4DCFF, dark: 0x3A2F66), Color(light: 0xC9B9FF, dark: 0x4F3FA0),
        Color(light: 0xA68FFF, dark: 0x6A54D6), Color(light: 0x7C5CFF, dark: 0x8E72FF), Color(light: 0x5432D9, dark: 0xB7A4FF),
    ]
    /// Muscle map: a muscle that is falling behind. Orange, never yellow.
    static let lagging = Color(light: 0xFF9F6B, dark: 0xFF9F6B)
    /// Muscle map: the whole figure when nothing is highlighted.
    static let figure = Color(light: 0xDAD7E0, dark: 0x36333E)

    /// Fixed colors for the camera, over a photo. They do not follow light and dark mode.
    enum Camera {
        static let scrim = Color(hex: 0x111015, opacity: 0.42)
        static let shade = Color(hex: 0x0E0D12)
        static let card = Color(hex: 0x18161E, opacity: 0.86)
        static let glass = Color.white.opacity(0.14)
        static let tag = Color.white.opacity(0.94)
        static let tagInk = Color(hex: 0x1D1B22)
        static let muted = Color(hex: 0xADA3D6)
        static let scanFigure = Color(hex: 0xA68FFF)  // the striped body in the scan, the same in light and dark
    }
}

nonisolated extension Color {
    fileprivate init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255,
            opacity: opacity)
    }
}

enum AZRadius {
    static let card: CGFloat = 22
    static let row: CGFloat = 16
    static let tile: CGFloat = 14
    static let control: CGFloat = 18
}

enum AZSpacing {
    /// Side gutter on every screen.
    static let gutter: CGFloat = 24
    static let section: CGFloat = 28
    static let stack: CGFloat = 12
}

nonisolated extension Color {
    /// A color that follows light and dark mode.
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { @Sendable in $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
        #else
        self.init(
            nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light) })
        #endif
    }
}

#if canImport(UIKit)
nonisolated extension UIColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#else
nonisolated extension NSColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#endif
