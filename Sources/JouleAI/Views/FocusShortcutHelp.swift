import AppKit

/// Messages about the Focus shortcut, so a missing or broken shortcut is never
/// a silent failure.
@MainActor
enum FocusShortcutHelp {

    /// Shown the first time JouleAI finds the Focus shortcut missing: what's
    /// wrong and the exact steps to fix it. Never shown again after that.
    static func showOnce(missing name: String) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppSettings.Key.focusMissingAlertShown) else { return }
        defaults.set(true, forKey: AppSettings.Key.focusMissingAlertShown)

        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Focus didn’t turn on"
        alert.informativeText = """
        JouleAI turns Focus on by running a shortcut named “\(name)”, and there isn’t one on this Mac yet.

        To create it:
        1. Open the Shortcuts app and click +.
        2. Name it exactly “\(name)”.
        3. Add the action “Set Focus”, choose Do Not Disturb (or any Focus) and set it to On.
        4. Make a second one named “\(AppSettings.focusOffShortcut)” that sets the same Focus to Off.

        You can change the names, or switch this off, in JouleAI Settings → Focus.
        """
        alert.addButton(withTitle: "Open Shortcuts")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
        }
    }

    /// The shortcut exists but failed to run: show the error it gave.
    static func showFailure(name: String, result: FocusShortcut.Result) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "The Focus shortcut “\(name)” failed"
        alert.informativeText = "\(result.logText)\n\nTry running it once in the Shortcuts app: macOS sometimes asks for a permission the first time."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
