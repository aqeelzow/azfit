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
    static let fill = Color(light: 0xF5F4F7, dark: 0x1E1C23)
    static let track = Color(light: 0xEEECF2, dark: 0x2A2730)
    static let hairline = Color(light: 0xECEAF0, dark: 0x24222A)
    static let card = Color(light: 0xFFFFFF, dark: 0x2C2934)

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

extension Color {
    /// A color that follows light and dark mode.
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
        #else
        self.init(
            nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light) })
        #endif
    }
}

#if canImport(UIKit)
extension UIColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#else
extension NSColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#endif
