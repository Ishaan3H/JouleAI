import Carbon.HIToolbox
import Foundation

/// A system-wide keyboard shortcut (works whichever app is in front).
///
/// Uses macOS's long-standing Carbon hotkey API: it needs no Accessibility
/// permission, because it only ever hears this one key combination, never
/// your other typing.
final class GlobalHotKey {

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let keyCode: UInt32
    private let modifiers: UInt32
    private let action: () -> Void

    /// Defaults to ⌘⇧J.
    init(keyCode: Int = kVK_ANSI_J, modifiers: Int = cmdKey | shiftKey, action: @escaping () -> Void) {
        self.keyCode = UInt32(keyCode)
        self.modifiers = UInt32(modifiers)
        self.action = action
    }

    var isRegistered: Bool { hotKeyRef != nil }

    /// Starts listening for the shortcut.
    func register() {
        guard hotKeyRef == nil else { return }

        // 1. A handler macOS calls when any of our hotkeys is pressed. It has
        //    to be a plain C function, so it finds this object through `userData`.
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hotKey.action() }
            return noErr
        }, 1, &eventType, selfPointer, &handlerRef)

        // 2. The key combination itself. The ID's signature is any 4 letters ("JLOT").
        let id = EventHotKeyID(signature: OSType(0x4A4C_4F54), id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            print("JouleAI: couldn't register the parking-lot shortcut (\(status)); another app may use it")
        }
    }

    /// Stops listening.
    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }

    deinit { unregister() }
}
