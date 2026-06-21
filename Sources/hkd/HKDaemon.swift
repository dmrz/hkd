//
//  HKDaemon.swift
//  hkd
//
//  Created by Dima on 21.06.2026.
//


import Foundation
import Cocoa

final class HKDaemon: @unchecked Sendable {
    
    private let configURL: URL
    private var config: AppConfig
    private var hotKeyMap: [HotKey: String] = [:]
    private var eventTap: CFMachPort?
    private var fileSystemWatcher: DispatchSourceFileSystemObject?
    private var permissionTimer: DispatchSourceTimer?
    
    private var installFailureCount = 0
    private let maxInstallFailures = 3
    
    init(configURL: URL) {
        self.configURL = configURL
        self.config = ConfigLoader.load(from: configURL)
        _ = NSWorkspace.shared
        rebuildHotKeyMap()
        print("Loaded \(config.hotkeys.count) hotkeys.")
    }
    
    // MARK: HotKey Map
    private func rebuildHotKeyMap() {
        hotKeyMap = Dictionary(
            config.hotkeys.map {
                (HotKey(keyCode: $0.keyCode, modifiers: $0.cgModifiers), $0.application)
            },
            uniquingKeysWith: { _, last in last }
        )
    }
    
    // MARK: Startup
    func start() {
        setupFileWatcher()
        startPermissionMonitor()
    }
    
    // MARK: Permission Monitor
    private func startPermissionMonitor() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + 2.0, repeating: 2.0)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let trusted = self.isAccessibilityTrusted(prompt: false)
            let tapExists = self.eventTap != nil
            let stalledOnFailures = self.installFailureCount >= self.maxInstallFailures
            
            if trusted && !tapExists && !stalledOnFailures {
                print("✅ Accessibility permission detected. Installing event tap...")
                DispatchQueue.main.async { [weak self] in
                    self?.installEventTap()
                }
            } else if !trusted && tapExists {
                print("⚠️ Accessibility permission revoked. Removing event tap...")
                self.installFailureCount = 0
                DispatchQueue.main.async { [weak self] in
                    self?.removeEventTap()
                }
            } else if !trusted && stalledOnFailures {
                self.installFailureCount = 0
            }
        }
        permissionTimer = timer
        permissionTimer?.resume()
        
        if isAccessibilityTrusted(prompt: false) {
            installEventTap()
        } else {
            print("⚠️ Accessibility permission not granted.")
            _ = isAccessibilityTrusted(prompt: true)
        }
    }
    
    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    // MARK: Event Tap
    private func installEventTap() {
        guard eventTap == nil else { return }
        
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: HKDaemon.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let tap = tap else {
            installFailureCount += 1
            print("⚠️ Could not create event tap (failure \(installFailureCount)/\(maxInstallFailures)).")
            if installFailureCount >= maxInstallFailures {
                print("⚠️ Repeated install failures — permission cache likely stale. Backing off.")
            }
            return
        }
        
        installFailureCount = 0
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("✅ Event tap installed.")
    }
    
    private func removeEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        print("🔴 Event tap removed.")
    }
    
    // MARK: C Callback
    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
        let daemon = Unmanaged<HKDaemon>.fromOpaque(userInfo).takeUnretainedValue()
        return daemon.handleEvent(proxy: proxy, type: type, event: event)
    }
    
    private func handleEvent(proxy: CGEventTapProxy?, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        
        if type == .tapDisabledByUserInput {
            print("⚠️ Event tap disabled by user input. Removing...")
            DispatchQueue.main.async { [weak self] in
                self?.removeEventTap()
            }
            return nil
        }
        
        if type == .tapDisabledByTimeout {
            print("⚠️ Event tap timed out. Removing immediately.")
            DispatchQueue.main.async { [weak self] in
                self?.removeEventTap()
            }
            return nil
        }
        
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }
        
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
        let key = HotKey(keyCode: keyCode, modifiers: modifiers)
        
        if let appName = hotKeyMap[key] {
            print("Matched hotkey for \(appName). Launching...")
            DispatchQueue.main.async { [weak self] in
                self?.launch(appName: appName)
            }
            return nil
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    // MARK: App Launching
    private func launch(appName: String) {
        let workspace = NSWorkspace.shared
        var appURL: URL?
        
        appURL = workspace.urlForApplication(withBundleIdentifier: appName)
            ?? workspace.urlForApplication(withBundleIdentifier: "com.apple." + appName)
            ?? workspace.urlForApplication(withBundleIdentifier: "com.apple." + appName.lowercased())
        
        if appURL == nil {
            for dir in ["/Applications", "/System/Applications", "/System/Applications/Utilities"] {
                let path = "\(dir)/\(appName).app"
                if FileManager.default.fileExists(atPath: path) {
                    appURL = URL(fileURLWithPath: path)
                    break
                }
            }
        }
        
        guard let targetURL = appURL else {
            print("❌ Could not find application: \(appName)")
            return
        }
        
        workspace.openApplication(at: targetURL, configuration: .init()) { _, error in
            if let error = error {
                print("❌ Failed to launch \(appName): \(error.localizedDescription)")
            } else {
                print("✅ Launched \(appName)")
            }
        }
    }
    
    // MARK: File Watcher
    private func setupFileWatcher() {
        let configDir = configURL.deletingLastPathComponent()
        let fd = open(configDir.path, O_EVTONLY)
        guard fd >= 0 else {
            print("⚠️ Could not watch config directory.")
            return
        }
        
        let watcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write],
            queue: DispatchQueue.global()
        )
        
        var pendingReload: DispatchWorkItem?
        
        watcher.setEventHandler { [weak self] in
            print("⚡️ Config change detected...")
            pendingReload?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.config = ConfigLoader.load(from: self.configURL)
                self.rebuildHotKeyMap()
                print("🔄 Reloaded \(self.config.hotkeys.count) hotkeys.")
            }
            pendingReload = item
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1, execute: item)
        }
        
        watcher.setCancelHandler { close(fd) }
        fileSystemWatcher = watcher
        fileSystemWatcher?.resume()
        print("Watching \(configDir.path) for changes...")
    }
}
