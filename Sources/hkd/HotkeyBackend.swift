/// A strategy for listening to global hotkeys.
@MainActor
protocol HotkeyBackend: AnyObject {
    var kind: HotkeyBackendKind { get }

    /// Replaces the active bindings, starting the backend if necessary.
    func activate(bindings: [Binding])

    /// Stops listening and releases all system resources.
    func deactivate()
}

enum HotkeyBackendKind: CustomStringConvertible {
    /// `RegisterEventHotKey`; needs no permissions but every hotkey must
    /// include at least one modifier.
    case carbon
    /// A CGEvent tap; handles any hotkey but requires the Accessibility
    /// permission.
    case eventTap

    var description: String {
        switch self {
        case .carbon: "Carbon hotkey API (no permissions required)"
        case .eventTap: "event tap (requires Accessibility permission)"
        }
    }

    /// Carbon can only register hotkeys that include a modifier; a single
    /// modifier-less hotkey forces the event tap for the whole set.
    static func required(for bindings: [Binding]) -> HotkeyBackendKind {
        bindings.contains { $0.hotkey.modifiers.isEmpty } ? .eventTap : .carbon
    }
}
