//
//  main.swift
//  hkd
//
//  Created by Dima on 19.06.2026.
//

import Foundation
import CoreGraphics

// Check if the arguments contain the version flag
// TODO: Use swift-argument-parser if more than just a version is needed
if CommandLine.arguments.contains("--version") || CommandLine.arguments.contains("-v") {
    print("0.1.0")
    exit(0) // Exit cleanly so the rest of the app doesn't execute
}

let daemonName = "hkd"
let home = FileManager.default.homeDirectoryForCurrentUser
let configURL = home.appending(components: ".config", daemonName, "config.json")

let daemon = HKDaemon(configURL: configURL)
daemon.start()

print("Daemon running. Monitoring keys...")
CFRunLoopRun()
