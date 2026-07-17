import Carbon.HIToolbox
import CoreGraphics

/// A modifier key, convertible to its CoreGraphics and Carbon representations.
enum Modifier: String, CaseIterable {
    case control, option, shift, command

    /// Display order following the macOS convention (⌃⌥⇧⌘).
    static let canonicalOrder: [Modifier] = [.control, .option, .shift, .command]

    init?(_ token: String) {
        switch token.lowercased() {
        case "cmd", "command": self = .command
        case "shift": self = .shift
        case "alt", "opt", "option": self = .option
        case "ctrl", "control": self = .control
        default: return nil
        }
    }

    var cgFlag: CGEventFlags {
        switch self {
        case .command: .maskCommand
        case .shift: .maskShift
        case .option: .maskAlternate
        case .control: .maskControl
        }
    }

    var carbonFlag: UInt32 {
        switch self {
        case .command: UInt32(cmdKey)
        case .shift: UInt32(shiftKey)
        case .option: UInt32(optionKey)
        case .control: UInt32(controlKey)
        }
    }
}

/// A key plus its modifiers.
struct Hotkey: Hashable {
    let keyCode: CGKeyCode
    let modifiers: Set<Modifier>

    var cgFlags: CGEventFlags {
        modifiers.reduce(into: CGEventFlags()) { $0.insert($1.cgFlag) }
    }

    var carbonFlags: UInt32 {
        modifiers.reduce(0) { $0 | $1.carbonFlag }
    }
}

/// Maps key names from the config file to macOS virtual key codes.
enum KeyName {
    static func keyCode(for token: String) -> CGKeyCode? {
        codes[token.lowercased()].map(CGKeyCode.init)
    }

    private static let codes: [String: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
        "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
        "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
        "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
        "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
        "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
        "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        "space": kVK_Space, "tab": kVK_Tab,
        "return": kVK_Return, "enter": kVK_Return,
        "escape": kVK_Escape, "esc": kVK_Escape,
        "delete": kVK_Delete, "backspace": kVK_Delete,
        "left": kVK_LeftArrow, "right": kVK_RightArrow,
        "up": kVK_UpArrow, "down": kVK_DownArrow,
        "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3, "f4": kVK_F4,
        "f5": kVK_F5, "f6": kVK_F6, "f7": kVK_F7, "f8": kVK_F8,
        "f9": kVK_F9, "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,
    ]
}
