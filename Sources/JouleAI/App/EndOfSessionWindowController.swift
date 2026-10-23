import AppKit
import SwiftUI

/// Shows the end-of-session window: a small floating panel (not full-screen).
///
/// Like the overlay, it's a "non-activating" panel, so it can take your typing
/// even if macOS keeps another app in front. Closing it with the red button
/// counts as Skip.
@MainActor
final class EndOfSessionWindowController: NSObject, NSWindowDelegate {

    private var panel: NSPanel?
    /// What to do if the window is closed without Save or Skip.
    private var onClose: (() -> Void)?

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(title: String, endedEarly: Bool,
              onSave: @escaping (Session.Outcome?, String) -> Void,
              onSkip: @escaping () -> Void) {
        close()

        let view = EndOfSessionView(
            title: title,
            endedEarly: endedEarly,
            onSave: { [weak self] outcome, note in
                self?.finish()
                onSave(outcome, note)
            },
            onSkip: { [weak self] in
                self?.finish()
                onSkip()
            }
        )
        onClose = onSkip

        let panel = NSPanel(contentViewController: NSHostingController(rootView: view))
        panel.styleMask = [.titled, .closable, .fullSizeContentView, .nonactivatingPanel]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = .floating                       // stays above normal windows
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.center()
        self.panel = panel

        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Closes the window without counting it as a skip (Save or Skip already ran).
    private func finish() {
        onClose = nil
        close()
    }

    private func close() {
        panel?.delegate = nil
        panel?.close()
        panel = nil
    }

    // MARK: - NSWindowDelegate

    /// The red close button: treat it as Skip.
    func windowWillClose(_ notification: Notification) {
        let skip = onClose
        onClose = nil
        panel = nil
        skip?()
    }
}
