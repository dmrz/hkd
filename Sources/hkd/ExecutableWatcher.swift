import Foundation

/// Exits the process when the running executable is replaced or removed on
/// disk — which is what `brew upgrade` does. Under launchd with `keep_alive`
/// (the brew service setup), exiting lets launchd relaunch the daemon, so an
/// upgrade takes effect without a manual service restart.
final class ExecutableWatcher {
    private let source: DispatchSourceFileSystemObject

    init?() {
        guard let path = Bundle.main.executableURL?.resolvingSymlinksInPath().path else {
            return nil
        }
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.delete, .rename, .write],
            queue: .main
        )
        source.setCancelHandler { close(descriptor) }
        source.setEventHandler {
            Log.info("Executable was replaced on disk; exiting so the service manager can relaunch the new version.")
            exit(EXIT_SUCCESS)
        }
        source.resume()
    }
}
