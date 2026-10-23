import AppKit
import SwiftUI

/// Shows and hides the blur overlay across every connected display.
///
/// Every screen gets an `OverlayPanel` (just blur). The main screen's panel also
/// hosts a SwiftUI "card" in the middle. The card is passed in by the caller, so
/// the same overlay shows the "time to start" card and the "you're in a
/// committed session" lock card.
@MainActor
final class OverlayController {

    private var panels: [OverlayPanel] = []
    /// The panel with the card; the only one that takes keyboard input.
    private var keyPanel: OverlayPanel?
    /// The card currently shown, kept so we can rebuild if displays change.
    private var currentCard: AnyView?
    /// Notification observers that only matter while the overlay is visible.
    private var visibleObservers: [NSObjectProtocol] = []

    var isVisible: Bool { !panels.isEmpty }

    init() {
        // If a display is plugged in or removed while the overlay is up,
        // rebuild so every screen stays covered.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, let card = self.currentCard else { return }
                self.show(card)
            }
        }
    }

    /// Covers every screen and shows `card` centred on the main screen.
    /// Calling it again while visible swaps in the new card.
    func show<Card: View>(_ card: Card) {
        hide()
        let card = AnyView(card)   // AnyView lets us store any kind of SwiftUI view
        currentCard = card

        // The first screen in the list is the one with the menu bar.
        let mainScreen = NSScreen.screens.first

        for screen in NSScreen.screens {
            let isMain = (screen == mainScreen)
            let panel = OverlayPanel(screen: screen, acceptsKeyboard: isMain)

            if isMain, let blur = panel.contentView {
                // NSHostingView puts a SwiftUI view inside an AppKit view.
                let host = NSHostingView(rootView: OverlayBackdrop(content: card))
                host.frame = blur.bounds
                host.autoresizingMask = [.width, .height]
                blur.addSubview(host)
                keyPanel = panel
            }

            panel.orderFrontRegardless()
            panels.append(panel)
        }

        // Ask to become the front app (macOS may decline; the non-activating
        // panel takes the keyboard either way).
        NSApp.activate()
        grabKeyboard()
        startHoldingKeyboard()
    }

    /// Removes the overlay from every screen.
    func hide() {
        for observer in visibleObservers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        visibleObservers.removeAll()

        for panel in panels {
            panel.orderOut(nil)
        }
        panels.removeAll()
        keyPanel = nil
        currentCard = nil
    }

    /// Makes the card's panel the window that receives key presses.
    func grabKeyboard() {
        keyPanel?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Private

    /// While visible, take the keyboard straight back whenever something else
    /// grabs it — e.g. Cmd+Tab to another app, or that app opening a window.
    private func startHoldingKeyboard() {
        guard let keyPanel else { return }

        let lostKey = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: keyPanel, queue: .main
        ) { [weak self] _ in
            // A tiny delay lets the other app finish its switch before we take
            // focus back; otherwise it can win the race.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                Task { @MainActor in self?.grabKeyboard() }
            }
        }

        let appSwitched = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                Task { @MainActor in self?.grabKeyboard() }
            }
        }

        visibleObservers = [lostKey, appSwitched]
    }
}

/// Darkens the blur slightly and centres the card.
private struct OverlayBackdrop: View {
    let content: AnyView

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
            content
        }
        .ignoresSafeArea()
    }
}
