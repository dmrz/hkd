import Foundation

/// Watches the config file and invokes `onChange` (debounced) whenever it
/// changes. Two dispatch sources cover the two ways editors save: a directory
/// source catches atomic replaces, creation, and deletion, while a file source
/// catches in-place writes. The file source is re-armed after every change
/// because a replace or delete leaves it pointing at the old inode.
@MainActor
final class ConfigWatcher {
    private let fileURL: URL
    private let onChange: @MainActor () -> Void
    private let directorySource: DispatchSourceFileSystemObject
    private var fileSource: DispatchSourceFileSystemObject?
    private var pendingChange: Task<Void, Never>?

    init?(fileURL: URL, onChange: @escaping @MainActor () -> Void) {
        let directory = fileURL.deletingLastPathComponent()
        guard let source = Self.makeSource(path: directory.path, eventMask: .write) else {
            Log.warn("Cannot watch \(directory.path); config changes will not auto-reload.")
            return nil
        }

        self.fileURL = fileURL
        self.onChange = onChange
        directorySource = source

        directorySource.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.scheduleChange()
            }
        }
        directorySource.resume()
        watchFile()
        Log.info("Watching \(fileURL.path) for changes.")
    }

    private func watchFile() {
        fileSource?.cancel()
        fileSource = nil

        guard let source = Self.makeSource(path: fileURL.path, eventMask: [.write, .extend, .delete, .rename]) else {
            return
        }
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.scheduleChange()
            }
        }
        source.resume()
        fileSource = source
    }

    private func scheduleChange() {
        pendingChange?.cancel()
        pendingChange = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self else { return }
            self.watchFile()
            self.onChange()
        }
    }

    private static func makeSource(path: String, eventMask: DispatchSource.FileSystemEvent) -> DispatchSourceFileSystemObject? {
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: eventMask,
            queue: .main
        )
        source.setCancelHandler { close(descriptor) }
        return source
    }
}
