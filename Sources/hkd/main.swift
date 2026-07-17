import Cocoa

let hkdVersion = "0.2.1"

let helpText = """
hkd \(hkdVersion) — a minimal macOS hotkey daemon

USAGE: hkd [options]

OPTIONS:
  -c, --config <path>   Path to the config file
                        (default: ~/.config/hkd/config.json)
      --verbose         Also log every hotkey match (useful when
                        setting up or debugging a config)
  -v, --version         Print the version and exit
  -h, --help            Show this help and exit
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("hkd: \(message)\n".utf8))
    exit(EXIT_FAILURE)
}

var configPathOverride: String?
var arguments = CommandLine.arguments.dropFirst().makeIterator()
while let argument = arguments.next() {
    switch argument {
    case "-v", "--version":
        print(hkdVersion)
        exit(EXIT_SUCCESS)
    case "-h", "--help":
        print(helpText)
        exit(EXIT_SUCCESS)
    case "-c", "--config":
        guard let path = arguments.next() else { fail("missing value for \(argument)") }
        configPathOverride = path
    case "--verbose":
        Log.isVerbose = true
    default:
        fail("unknown option \(argument); see hkd --help")
    }
}

let configURL = if let configPathOverride {
    URL(fileURLWithPath: (configPathOverride as NSString).expandingTildeInPath)
} else {
    FileManager.default.homeDirectoryForCurrentUser
        .appending(components: ".config", "hkd", "config.json")
}

let daemon = Daemon(configURL: configURL)
daemon.start()

// The Cocoa event loop dispatches Carbon hotkey events and services the main
// run loop (event tap, timers, dispatch sources).
NSApplication.shared.run()
