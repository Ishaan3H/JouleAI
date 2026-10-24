import AppKit

/// User preferences, stored in `UserDefaults` (macOS's built-in key–value store
/// for small settings).
///
/// The `Key` names are shared with the Settings screen, which reads and writes
/// the same values through SwiftUI's `@AppStorage`.
enum AppSettings {

    enum Key {
        static let defaultDurationMinutes = "defaultDurationMinutes"
        static let focusEnabled = "focusEnabled"
        static let focusOnShortcut = "focusOnShortcut"
        static let focusOffShortcut = "focusOffShortcut"
        static let focusShortcutMissing = "focusShortcutMissing"
        static let focusHintDismissed = "focusHintDismissed"
        static let focusMissingAlertShown = "focusMissingAlertShown"
        static let titleCheckExplained = "titleCheckExplained"
        static let brownNoiseEnabled = "brownNoiseEnabled"
        static let brownNoiseVolume = "brownNoiseVolume"
        static let sessionBrowser = "sessionBrowser"
        static let parkingLotCorner = "parkingLotCorner"
    }

    /// The values used until the user changes them. Called once at launch.
    /// `register` doesn't overwrite anything the user has set; it only fills gaps.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.defaultDurationMinutes: 25,
            Key.focusEnabled: true,
            Key.focusOnShortcut: "JouleAI Focus On",
            Key.focusOffShortcut: "JouleAI Focus Off",
            Key.focusShortcutMissing: false,
            Key.focusHintDismissed: false,
            Key.brownNoiseEnabled: true,
            Key.brownNoiseVolume: 0.3,
            Key.sessionBrowser: defaultSessionBrowser,
            Key.parkingLotCorner: ScreenCorner.bottomRight.rawValue,
        ])
    }

    private static var defaults: UserDefaults { .standard }

    /// The session length new commitments start with.
    static var defaultDurationMinutes: Int {
        get { defaults.integer(forKey: Key.defaultDurationMinutes) }
        set { defaults.set(newValue, forKey: Key.defaultDurationMinutes) }
    }

    /// Run the Focus shortcut when a session starts.
    static var focusEnabled: Bool { defaults.bool(forKey: Key.focusEnabled) }
    static var focusOnShortcut: String { defaults.string(forKey: Key.focusOnShortcut) ?? "" }
    static var focusOffShortcut: String { defaults.string(forKey: Key.focusOffShortcut) ?? "" }

    /// Set when JouleAI tried to run a Focus shortcut that doesn't exist, so the
    /// Settings screen can show a hint about creating it.
    static var focusShortcutMissing: Bool {
        get { defaults.bool(forKey: Key.focusShortcutMissing) }
        set { defaults.set(newValue, forKey: Key.focusShortcutMissing) }
    }

    /// Records that a missing Focus shortcut was noticed. The hint only appears
    /// once: after "Got it" is pressed, it never comes back.
    static func noteFocusShortcutMissing() {
        if !defaults.bool(forKey: Key.focusHintDismissed) {
            focusShortcutMissing = true
        }
    }

    /// Bundle ID of the browser that web targets open in and whose tabs the
    /// lock watches (it must support AppleScript; see BrowserTabs).
    static var sessionBrowserID: String { defaults.string(forKey: Key.sessionBrowser) ?? "" }

    /// Chrome if it's installed, otherwise Safari (always present on a Mac).
    private static var defaultSessionBrowser: String {
        let chrome = "com.google.Chrome"
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: chrome) != nil
            ? chrome : "com.apple.Safari"
    }

    /// Where the parking-lot pad docks.
    static var parkingLotCorner: ScreenCorner {
        get { ScreenCorner(rawValue: defaults.string(forKey: Key.parkingLotCorner) ?? "") ?? .bottomRight }
        set { defaults.set(newValue.rawValue, forKey: Key.parkingLotCorner) }
    }

    static var brownNoiseEnabled: Bool { defaults.bool(forKey: Key.brownNoiseEnabled) }
    /// 0.0 (silent) to 1.0 (full).
    static var brownNoiseVolume: Float { defaults.float(forKey: Key.brownNoiseVolume) }
}

/// A corner of the screen, for docking the parking-lot pad.
enum ScreenCorner: String, CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    var label: String {
        switch self {
        case .topLeft: return "Top left"
        case .topRight: return "Top right"
        case .bottomLeft: return "Bottom left"
        case .bottomRight: return "Bottom right"
        }
    }
}
