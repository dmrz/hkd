import Foundation

/// Owns the config lifecycle and routes bindings to the appropriate backend:
/// the permission-free Carbon API when every hotkey includes a modifier, or a
/// CGEvent tap (Accessibility permission) when any hotkey has none.
@MainActor
final class Daemon {
    private let configURL: URL
    private let launcher = AppLauncher()
    private var watcher: ConfigWatcher?
    private var backend: (any HotkeyBackend)?
    private var currentConfig = Config.empty

    init(configURL: URL) {
        self.configURL = configURL
    }

    func start() {
        Log.info("hkd \(hkdVersion) starting (config: \(configURL.path)).")

        switch ConfigLoader.load(from: configURL) {
        case .loaded(let config):
            apply(config)
        case .missing:
            Log.warn("No config file found; waiting for it to be created.")
            apply(.empty)
        case .invalid(let reason):
            Log.error("Invalid config, starting without hotkeys: \(reason)")
            apply(.empty)
        }

        watcher = ConfigWatcher(fileURL: configURL) { [weak self] in
            self?.reload()
        }
    }

    private func reload() {
        switch ConfigLoader.load(from: configURL) {
        case .loaded(let config):
            guard config != currentConfig else { return }
            Log.info("Config changed; reloading.")
            apply(config)
        case .missing:
            guard currentConfig != .empty else { return }
            Log.warn("Config file removed; deactivating all hotkeys.")
            apply(.empty)
        case .invalid(let reason):
            Log.error("Invalid config, keeping the previous hotkeys: \(reason)")
        }
    }

    private func apply(_ config: Config) {
        currentConfig = config
        let bindings = Self.deduplicated(config.bindings)
        let desiredKind = HotkeyBackendKind.required(for: bindings)

        if let backend, backend.kind != desiredKind {
            backend.deactivate()
            self.backend = nil
        }
        if backend == nil {
            Log.info("Using the \(desiredKind).")
            backend = makeBackend(desiredKind)
        }

        backend?.activate(bindings: bindings)
        Log.info("Active hotkeys: \(bindings.count).")
    }

    /// Collapses bindings that share a hotkey, keeping the last definition
    /// in its original position.
    nonisolated static func deduplicated(_ bindings: [Binding]) -> [Binding] {
        var indexByHotkey: [Hotkey: Int] = [:]
        var result: [Binding] = []
        for binding in bindings {
            if let existing = indexByHotkey[binding.hotkey] {
                Log.warn("Duplicate hotkey \(binding.name); using the last definition.")
                result[existing] = binding
            } else {
                indexByHotkey[binding.hotkey] = result.count
                result.append(binding)
            }
        }
        return result
    }

    private func makeBackend(_ kind: HotkeyBackendKind) -> any HotkeyBackend {
        let onTrigger: @MainActor (Binding) -> Void = { [launcher] binding in
            Log.info("\(binding.name) → \(binding.application)")
            launcher.launch(binding.application)
        }
        switch kind {
        case .carbon:
            return CarbonHotkeyBackend(onTrigger: onTrigger)
        case .eventTap:
            return EventTapBackend(onTrigger: onTrigger)
        }
    }
}
