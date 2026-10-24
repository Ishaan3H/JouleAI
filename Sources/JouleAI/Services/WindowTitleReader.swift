import AppKit
import ApplicationServices

/// Reads the title of a browser's front window through macOS's Accessibility
/// API. Used for Firefox-based browsers (Firefox, Zen), whose tab addresses
/// can't be read with AppleScript.
///
/// This needs the Accessibility permission (System Settings → Privacy &
/// Security → Accessibility). JouleAI only reads the front window's title of
/// those browsers during a session; it never reads keystrokes or page content.
enum WindowTitleReader {

    /// True once Accessibility permission has been granted to JouleAI.
    static var isAllowed: Bool { AXIsProcessTrusted() }

    /// Shows macOS's own permission prompt (it offers to open System Settings).
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings at Privacy & Security → Accessibility.
    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// The title of the focused window of the app with this process ID, e.g.
    /// "Calculus | Khan Academy — Zen Browser". Nil without permission or window.
    static func frontWindowTitle(processID: pid_t) -> String? {
        let app = AXUIElementCreateApplication(processID)
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let windowValue, CFGetTypeID(windowValue) == AXUIElementGetTypeID() else { return nil }
        let window = windowValue as! AXUIElement   // checked just above

        var titleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success
        else { return nil }
        return titleValue as? String
    }
}
