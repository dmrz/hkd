import Foundation

/// Minimal timestamped logging: info to stdout, warnings and errors to stderr.
/// Debug messages are only emitted when `--verbose` is set.
enum Log {
    /// Set once during argument parsing, before any concurrent code runs.
    nonisolated(unsafe) static var isVerbose = false

    static func debug(_ message: String) {
        guard isVerbose else { return }
        write(message, to: .standardOutput)
    }

    static func info(_ message: String) {
        write(message, to: .standardOutput)
    }

    static func warn(_ message: String) {
        write("warning: \(message)", to: .standardError)
    }

    static func error(_ message: String) {
        write("error: \(message)", to: .standardError)
    }

    private static func write(_ message: String, to handle: FileHandle) {
        let timestamp = Date.now.formatted(.iso8601)
        handle.write(Data("[\(timestamp)] \(message)\n".utf8))
    }
}
