import Carbon.HIToolbox
import Foundation

/// A system-wide keyboard shortcut (works whichever app is in front).
///
/// Uses macOS's long-standing Carbon hotkey API: it needs no Accessibility
/// permission, because it only ever hears this one key combination, never
/// your other typing. Several can exist at once (the parking lot's ⌘⇧J and
/// the emergency exit ⌃⌥⌘⎋); each only reacts to its own combination.
final class GlobalHotKey {

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let keyCode: UInt32
    private let modifiers: UInt32
    private let action: () -> Void

    /// A number unique to this shortcut, so its handler can tell its own key
    /// presses apart from another shortcut's.
    private let number: UInt32
    private static var nextNumber: UInt32 = 1

    /// Defaults to ⌘⇧J.
    init(keyCode: Int = kVK_ANSI_J, modifiers: Int = cmdKey | shiftKey, action: @escaping () -> Void) {
        self.keyCode = UInt32(keyCode)
        self.modifiers = UInt32(modifiers)
        self.action = action
        self.number = Self.nextNumber
        Self.nextNumber += 1
    }

    /// ⌃⌥⌘⎋ (Control-Option-Command-Escape): the emergency exit.
    static func emergencyExit(action: @escaping () -> Void) -> GlobalHotKey {
        GlobalHotKey(keyCode: kVK_Escape, modifiers: controlKey | optionKey | cmdKey, action: action)
    }

    var isRegistered: Bool { hotKeyRef != nil }

    /// Starts listening for the shortcut.
    func register() {
        guard hotKeyRef == nil else { return }

        // 1. A handler macOS calls when any of our hotkeys is pressed. It has
        //    to be a plain C function, so it finds this object through `userData`,
        //    then checks the pressed hotkey is this one.
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()

            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            // Someone else's shortcut: let the next handler have it.
            guard pressed.id == hotKey.number else { return OSStatus(eventNotHandledErr) }

            DispatchQueue.main.async { hotKey.action() }
            return noErr
        }, 1, &eventType, selfPointer, &handlerRef)

        // 2. The key combination itself. The ID's signature is any 4 letters ("JLOT").
        let id = EventHotKeyID(signature: OSType(0x4A4C_4F54), id: number)
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            print("JouleAI: couldn't register a global shortcut (\(status)); another app may use it")
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
