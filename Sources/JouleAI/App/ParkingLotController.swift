import AppKit
import SwiftUI

/// Shows and hides the parking-lot pad, docked to a screen corner.
///
/// The pad is a "non-activating" panel: it takes your typing without making
/// JouleAI the front app, so the app you're working in stays in charge (and
/// the session lock never sees an app switch). Its window level is one above
/// the lock overlay, so the lock can never cover it.
@MainActor
final class ParkingLotController {

    let model = ParkingLotModel()
    private var panel: ParkingLotPanel?
    /// Called whenever the text changes (the coordinator saves it).
    var onTextChange: ((String) -> Void)?

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        if panel == nil { makePanel() }
        model.corner = AppSettings.parkingLotCorner
        position()
        panel?.orderFrontRegardless()
        panel?.makeKey()          // take the keyboard for typing only
        model.focusRequest += 1
    }

    func hide() {
        panel?.orderOut(nil)      // the keyboard goes back to the app you were in
    }

    /// Clears the pad for a new session.
    func reset() {
        hide()
        model.text = ""
    }

    /// Moves the pad to another corner and remembers the choice.
    func move(to corner: ScreenCorner) {
        AppSettings.parkingLotCorner = corner
        model.corner = corner
        position()
    }

    // MARK: - Private

    private func makePanel() {
        let view = ParkingLotView(model: model,
                                  onClose: { [weak self] in self?.hide() },
                                  onMove: { [weak self] in self?.move(to: $0) },
                                  onTextChange: { [weak self] in self?.onTextChange?($0) })
        let panel = ParkingLotPanel(content: NSHostingView(rootView: view))
        panel.onEscape = { [weak self] in self?.hide() }
        self.panel = panel
    }

    /// Puts the pad in the chosen corner of the screen with the menu bar,
    /// inside the area not covered by the menu bar and Dock.
    private func position() {
        guard let panel, let screen = NSScreen.screens.first else { return }
        let area = screen.visibleFrame
        let size = panel.frame.size
        let margin: CGFloat = 16
        let x = (model.corner == .topLeft || model.corner == .bottomLeft)
            ? area.minX + margin : area.maxX - size.width - margin
        let y = (model.corner == .bottomLeft || model.corner == .bottomRight)
            ? area.minY + margin : area.maxY - size.height - margin
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// The pad's window: borderless, floating above everything (even the lock),
/// on every Space, and able to take typing without activating JouleAI.
final class ParkingLotPanel: NSPanel {

    var onEscape: (() -> Void)?

    init(content: NSView) {
        let size = content.fittingSize
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        contentView = content
        // One level above the lock overlay (.screenSaver), so it's never covered.
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
    }

    /// Borderless windows can't normally take typing; this one must.
    override var canBecomeKey: Bool { true }

    /// Escape hides the pad.
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}
