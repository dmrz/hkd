import Carbon.HIToolbox

/// Listens for hotkeys with Carbon's `RegisterEventHotKey`. Needs no special
/// permissions, but only supports combinations that include a modifier.
@MainActor
final class CarbonHotkeyBackend: HotkeyBackend {
    let kind: HotkeyBackendKind = .carbon

    private let onTrigger: (Binding) -> Void
    private var eventHandler: EventHandlerRef?
    private var registrations: [UInt32: (ref: EventHotKeyRef, binding: Binding)] = [:]
    private var nextID: UInt32 = 1

    private static let signature: OSType = "HKDM".utf8.reduce(0) { ($0 << 8) | OSType($1) }

    init(onTrigger: @escaping @MainActor (Binding) -> Void) {
        self.onTrigger = onTrigger
    }

    func activate(bindings: [Binding]) {
        unregisterAll()
        installHandlerIfNeeded()
        for binding in bindings {
            register(binding)
        }
    }

    func deactivate() {
        unregisterAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    // MARK: - Registration

    private func register(_ binding: Binding) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: nextID)
        let status = RegisterEventHotKey(
            UInt32(binding.hotkey.keyCode),
            binding.hotkey.carbonFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            Log.warn("Could not register \(binding.name) (status \(status)); it may be taken by the system or another app.")
            return
        }
        registrations[nextID] = (ref, binding)
        nextID += 1
    }

    private func unregisterAll() {
        for (_, registration) in registrations {
            UnregisterEventHotKey(registration.ref)
        }
        registrations = [:]
    }

    // MARK: - Event Handling

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            Self.hotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        if status != noErr {
            Log.error("Failed to install Carbon event handler (status \(status)).")
        }
    }

    private static let hotKeyHandler: EventHandlerUPP = { _, event, userInfo in
        guard let event, let userInfo else { return OSStatus(eventNotHandledErr) }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else { return status }

        let backend = Unmanaged<CarbonHotkeyBackend>.fromOpaque(userInfo).takeUnretainedValue()
        MainActor.assumeIsolated {
            backend.handleHotKey(hotKeyID)
        }
        return noErr
    }

    private func handleHotKey(_ id: EventHotKeyID) {
        guard id.signature == Self.signature, let registration = registrations[id.id] else { return }
        onTrigger(registration.binding)
    }
}
