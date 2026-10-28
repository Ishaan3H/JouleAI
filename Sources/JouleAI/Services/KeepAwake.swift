import Foundation
import IOKit.pwr_mgt

/// Keeps the display (and so the Mac) from going to sleep while a session runs.
///
/// It uses an IOKit "power assertion": a request to macOS that says "don't
/// idle-sleep the display right now, for this reason". It's the same thing the
/// `caffeinate` command does. The request lasts until it's released, so the
/// coordinator releases it on every way a session can end, and macOS drops it
/// automatically if JouleAI ever quits or crashes.
@MainActor
final class KeepAwake {

    private var assertionID: IOPMAssertionID = 0
    private(set) var isOn = false

    /// Asks macOS to keep the display awake. Returns false if it refused.
    @discardableResult
    func turnOn() -> Bool {
        guard !isOn else { return true }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Joule focus session" as CFString,   // shown by `pmset -g assertions`
            &assertionID
        )
        isOn = (result == kIOReturnSuccess)
        if !isOn { print("JouleAI: couldn't keep the Mac awake (IOKit error \(result))") }
        return isOn
    }

    /// Lets the Mac sleep normally again. Safe to call more than once.
    func turnOff() {
        guard isOn else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isOn = false
    }
}
