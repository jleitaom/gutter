import Carbon.HIToolbox

/// A system-wide keyboard shortcut. Registered on init, unregistered on deinit.
final class HotKey {
    private let id: UInt32
    private let action: () -> Void
    // Only touched on the main thread; `nonisolated(unsafe)` lets the nonisolated deinit release them.
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var handlerRef: EventHandlerRef?

    /// Fails when the shortcut can't be registered, e.g. another app holds it exclusively.
    /// Apps that register the same shortcut non-exclusively can't be detected.
    /// Each of the app's shortcuts needs its own `id`.
    init?(id: UInt32, keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.id = id
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            // Carbon delivers hot key events on the main thread.
            return MainActor.assumeIsolated {
                let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                // Every shortcut's handler sees every press; pass on the ones for another shortcut.
                guard pressed.id == hotKey.id else { return OSStatus(eventNotHandledErr) }
                hotKey.action()
                return noErr
            }
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x4755_5452), id: id) // "GUTR"
        // Exclusive, so registration fails (instead of silently sharing) when another app already claimed it.
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(),
                                         OptionBits(kEventHotKeyExclusive), &hotKeyRef)
        guard status == noErr else {
            NSLog("Gutter: couldn't register shortcut \(id) (\(status))")
            return nil // deinit removes the event handler
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
