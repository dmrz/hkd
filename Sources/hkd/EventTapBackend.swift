import Cocoa

/// Listens for hotkeys with a CGEvent tap. Handles any key combination,
/// including hotkeys without modifiers, but requires the Accessibility
/// permission. Grant and revocation are detected while running.
@MainActor
final class EventTapBackend: HotkeyBackend {
    let kind: HotkeyBackendKind = .eventTap

    private struct MatchKey: Hashable {
        let keyCode: Int64
        let flags: UInt64
    }

    private let onTrigger: (Binding) -> Void
    private var bindings: [MatchKey: Binding] = [:]
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: DispatchSourceTimer?

    /// Tap creation can keep failing while the TCC permission cache is stale;
    /// after a few attempts we back off until the permission is re-granted.
    private var consecutiveTapFailures = 0
    private static let maxTapFailures = 3

    init(onTrigger: @escaping @MainActor (Binding) -> Void) {
        self.onTrigger = onTrigger
    }

    func activate(bindings newBindings: [Binding]) {
        bindings = Dictionary(
            newBindings.map { binding in
                (MatchKey(keyCode: Int64(binding.hotkey.keyCode), flags: binding.hotkey.cgFlags.rawValue), binding)
            },
            uniquingKeysWith: { _, last in last }
        )
        startIfNeeded()
    }

    func deactivate() {
        permissionTimer?.cancel()
        permissionTimer = nil
        removeTap()
        bindings = [:]
        consecutiveTapFailures = 0
    }

    // MARK: - Accessibility Permission

    private func startIfNeeded() {
        guard permissionTimer == nil else { return }

        if isAccessibilityTrusted(prompting: false) {
            installTap()
        } else {
            Log.warn("Accessibility permission is required for hotkeys without modifiers; requesting it.")
            _ = isAccessibilityTrusted(prompting: true)
        }
        startPermissionMonitor()
    }

    private func isAccessibilityTrusted(prompting: Bool) -> Bool {
        // kAXTrustedCheckOptionPrompt; the constant is not concurrency-safe to import.
        return AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": prompting] as CFDictionary)
    }

    private func startPermissionMonitor() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .seconds(2), repeating: .seconds(2))
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.checkPermission()
            }
        }
        timer.resume()
        permissionTimer = timer
    }

    private func checkPermission() {
        if isAccessibilityTrusted(prompting: false) {
            if eventTap == nil && consecutiveTapFailures < Self.maxTapFailures {
                Log.info("Accessibility permission granted; installing event tap.")
                installTap()
            }
        } else {
            consecutiveTapFailures = 0
            if eventTap != nil {
                Log.warn("Accessibility permission revoked; removing event tap.")
                removeTap()
            }
        }
    }

    // MARK: - Event Tap

    private func installTap() {
        guard eventTap == nil else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: Self.tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            consecutiveTapFailures += 1
            Log.error("Failed to create event tap (attempt \(consecutiveTapFailures)/\(Self.maxTapFailures)).")
            if consecutiveTapFailures >= Self.maxTapFailures {
                Log.error("Backing off until the Accessibility permission is re-granted.")
            }
            return
        }

        consecutiveTapFailures = 0
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        Log.info("Event tap installed.")
    }

    private func removeTap() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let backend = Unmanaged<EventTapBackend>.fromOpaque(userInfo).takeUnretainedValue()
        // The tap's run loop source lives on the main run loop, so this
        // callback always runs on the main thread.
        nonisolated(unsafe) let event = event
        let consumed = MainActor.assumeIsolated {
            backend.handle(type: type, event: event)
        }
        return consumed ? nil : Unmanaged.passUnretained(event)
    }

    /// Returns true when the event matched a hotkey and must not reach other apps.
    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            Log.warn("Event tap disabled by the system; re-enabling.")
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return false

        case .keyDown:
            let key = MatchKey(
                keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                flags: event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]).rawValue
            )
            guard let binding = bindings[key] else { return false }
            let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !isAutorepeat {
                onTrigger(binding)
            }
            return true

        default:
            return false
        }
    }
}
