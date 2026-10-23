import AppKit

/// Calls `onTick` every 30 seconds, and also right after the Mac wakes from sleep.
///
/// The scheduler doesn't know anything about commitments; it just says "now is a
/// good moment to check". `SessionCoordinator` decides what to do with that.
@MainActor
final class Scheduler {

    private var timer: Timer?
    private let onTick: () -> Void

    init(onTick: @escaping () -> Void) {
        self.onTick = onTick
    }

    func start() {
        // A repeating timer. Adding it to the `.common` run-loop mode keeps it
        // firing even while a menu is open or a window is being dragged
        // (plain timers pause during those).
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.onTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // Timers don't fire while the Mac sleeps, so check again on wake.
        // The short delay gives displays a moment to come back before we
        // cover them with an overlay.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                Task { @MainActor in self?.onTick() }
            }
        }

        // And check once straight away at launch.
        onTick()
    }
}
