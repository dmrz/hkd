//
//  AppConfig.swift
//  hkd
//
//  Created by Dima on 21.06.2026.
//


import Foundation
import Cocoa
import CoreGraphics

struct AppConfig: Codable {
    let hotkeys: [HotKeyConfig]
}

struct HotKeyConfig: Codable {
    let key: String
    let modifiers: [String]
    let application: String
    
    var cgModifiers: CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains("cmd") { flags.insert(.maskCommand) }
        if modifiers.contains("shift") { flags.insert(.maskShift) }
        if modifiers.contains("alt") || modifiers.contains("option") { flags.insert(.maskAlternate) }
        if modifiers.contains("ctrl") || modifiers.contains("control") { flags.insert(.maskControl) }
        return flags
    }
    
    var keyCode: UInt16 {
        switch key.lowercased() {
        case "a": return 0;  case "s": return 1;  case "d": return 2
        case "f": return 3;  case "h": return 4;  case "g": return 5
        case "z": return 6;  case "x": return 7;  case "c": return 8
        case "v": return 9;  case "b": return 11; case "q": return 12
        case "w": return 13; case "e": return 14; case "r": return 15
        case "y": return 16; case "t": return 17; case "u": return 32
        case "i": return 34; case "o": return 31; case "p": return 35
        case "j": return 38; case "k": return 40; case "l": return 37
        case "m": return 46; case "n": return 45
        case "0": return 29; case "1": return 18; case "2": return 19
        case "3": return 20; case "4": return 21; case "5": return 23
        case "6": return 22; case "7": return 26; case "8": return 28
        case "9": return 25
        case "escape": return 53; case "space": return 49
        case "return", "enter": return 36; case "tab": return 48
        case "delete", "backspace": return 51
        case "left": return 123; case "right": return 124
        case "down": return 125; case "up": return 126
        case "f1": return 122; case "f2": return 120; case "f3": return 99
        case "f4": return 118; case "f5": return 96; case "f6": return 97
        case "f7": return 98; case "f8": return 100; case "f9": return 101
        case "f10": return 109; case "f11": return 103; case "f12": return 111
        default: return 0
        }
    }
}

struct HotKey: Hashable {
    let keyCode: UInt16
    let modifiersRawValue: UInt64
    
    init(keyCode: UInt16, modifiers: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiersRawValue = modifiers.rawValue
    }
}


class ConfigLoader {
    static func load(from url: URL) -> AppConfig {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            print("⚠️ Could not read or parse \(url.path). Running empty.")
            return AppConfig(hotkeys: [])
        }
        return decoded
    }
}

