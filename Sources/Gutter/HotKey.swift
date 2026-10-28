import Carbon.HIToolbox

/// A system-wide keyboard shortcut. Registered on init, unregistered on deinit.
final class HotKey {
    private let action: () -> Void
    // Only touched on the main thread; `nonisolated(unsafe)` lets the nonisolated deinit release them.
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var handlerRef: EventHandlerRef?

    /// Fails when the shortcut can't be registered, e.g. another app holds it exclusively.
    /// Apps that register the same shortcut non-exclusively can't be detected.
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            // Carbon delivers hot key events on the main thread.
            MainActor.assumeIsolated { Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue().action() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x4755_5452), id: 1) // "GUTR"
        // Exclusive, so registration fails (instead of silently sharing) when another app already claimed it.
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(),
                                         OptionBits(kEventHotKeyExclusive), &hotKeyRef)
        guard status == noErr else {
            NSLog("Gutter: couldn't register the shortcut (\(status))")
            return nil // deinit removes the event handler
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
