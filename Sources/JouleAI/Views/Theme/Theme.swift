import AppKit
import SwiftUI

/// JouleAI's look in one place: colours, type sizes, spacing and corner radii.
///
/// Every screen uses these names instead of raw values, so the whole app can
/// be retuned by editing this file. Each colour has a light and a dark version;
/// macOS picks the right one automatically when you switch appearance.
enum Theme {

    // MARK: Colours

    /// Warm off-white page background.
    static let background = Color(light: 0xF6F3EA, dark: 0x181714)
    /// Cards and panels sitting on the background.
    static let surface = Color(light: 0xFFFDF8, dark: 0x23211D)
    /// Inset areas: text fields, the left-off note.
    static let sunken = Color(light: 0xEEEADF, dark: 0x2C2A25)
    /// Hairline borders and dividers.
    static let border = Color(light: 0xE3DED0, dark: 0x37342E)

    /// Near-black main text.
    static let text = Color(light: 0x1C1B17, dark: 0xF2EFE7)
    /// Supporting text: times, descriptions.
    static let textSecondary = Color(light: 0x6C675B, dark: 0xA7A294)
    /// Least important text: section labels, placeholders.
    static let textTertiary = Color(light: 0x9A9588, dark: 0x78746A)

    /// Olive green: the one accent colour, used for the main action and "committed".
    static let accent = Color(light: 0x5D6B28, dark: 0xA6B661)
    /// A pale wash of the accent, for selected rows and soft highlights.
    static let accentSoft = Color(light: 0xE5E8D2, dark: 0x30351F)
    /// Text drawn on top of the accent colour.
    static let onAccent = Color(light: 0xFFFDF5, dark: 0x15160E)

    /// Muted amber for warnings (clashes, missing shortcut).
    static let warning = Color(light: 0x9C5F1C, dark: 0xE2A75C)
    /// Muted brick for destructive actions.
    static let danger = Color(light: 0xA3402F, dark: 0xE2826F)

    // MARK: Type
    // A clear hierarchy: one big thing per screen, then title, body, small.

    enum Font {
        /// The overlay card's title.
        static let display = SwiftUI.Font.system(size: 44, weight: .bold)
        /// The hero item in the popover, page titles in the window.
        static let title = SwiftUI.Font.system(size: 22, weight: .semibold)
        /// Row titles, field text.
        static let body = SwiftUI.Font.system(size: 14)
        static let bodyEmphasis = SwiftUI.Font.system(size: 14, weight: .semibold)
        /// Times and secondary details.
        static let detail = SwiftUI.Font.system(size: 12.5)
        /// Small uppercase labels above sections ("LATER TODAY").
        static let label = SwiftUI.Font.system(size: 10.5, weight: .semibold)
        /// Big countdown numbers.
        static let countdown = SwiftUI.Font.system(size: 40, weight: .medium, design: .rounded)
            .monospacedDigit()
        static let countdownSmall = SwiftUI.Font.system(size: 15, weight: .medium, design: .rounded)
            .monospacedDigit()
    }

    // MARK: Spacing & shape

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 20
    }
}

extension Color {
    /// A colour with separate light- and dark-mode values, given as hex like 0xF6F3EA.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
