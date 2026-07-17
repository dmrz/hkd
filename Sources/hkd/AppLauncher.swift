import Cocoa

/// Resolves an application reference — a bundle identifier or an app name —
/// and launches it.
@MainActor
final class AppLauncher {
    private static let searchDirectories = [
        "/Applications",
        NSHomeDirectory() + "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
    ]

    func launch(_ application: String) {
        guard let url = resolve(application) else {
            Log.error("Could not find application \"\(application)\".")
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                Log.error("Failed to launch \(application): \(error.localizedDescription)")
            }
        }
    }

    private func resolve(_ application: String) -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: application) {
            return url
        }
        return Self.searchDirectories
            .map { URL(fileURLWithPath: "\($0)/\(application).app") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
