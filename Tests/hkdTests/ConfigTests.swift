import Carbon.HIToolbox
import Foundation
import Testing

@testable import hkd

@Suite("Config loading")
struct ConfigLoaderTests {
    private func load(_ json: String) throws -> ConfigLoader.LoadResult {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hkd-test-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return ConfigLoader.load(from: url)
    }

    @Test func loadsValidConfig() throws {
        let result = try load("""
            {
              "hotkeys": [
                { "key": "b", "modifiers": ["cmd", "shift"], "application": "Safari" },
                { "key": "space", "modifiers": ["ctrl"], "application": "Terminal" }
              ]
            }
            """)
        guard case .loaded(let config) = result else {
            Issue.record("Expected .loaded, got \(result)")
            return
        }
        #expect(config.bindings.count == 2)

        let first = config.bindings[0]
        #expect(first.hotkey.keyCode == CGKeyCode(kVK_ANSI_B))
        #expect(first.hotkey.modifiers == [.command, .shift])
        #expect(first.application == "Safari")
        #expect(first.name == "shift+command+b")

        let second = config.bindings[1]
        #expect(second.hotkey.keyCode == CGKeyCode(kVK_Space))
        #expect(second.hotkey.modifiers == [.control])
    }

    @Test func modifiersAreOptional() throws {
        let result = try load("""
            { "hotkeys": [ { "key": "f1", "application": "Notes" } ] }
            """)
        guard case .loaded(let config) = result else {
            Issue.record("Expected .loaded, got \(result)")
            return
        }
        #expect(config.bindings[0].hotkey.modifiers.isEmpty)
    }

    @Test func rejectsUnknownKey() throws {
        let result = try load("""
            { "hotkeys": [ { "key": "f19", "modifiers": ["cmd"], "application": "Safari" } ] }
            """)
        guard case .invalid(let reason) = result else {
            Issue.record("Expected .invalid, got \(result)")
            return
        }
        #expect(reason.contains("f19"))
    }

    @Test func rejectsUnknownModifier() throws {
        let result = try load("""
            { "hotkeys": [ { "key": "a", "modifiers": ["hyper"], "application": "Safari" } ] }
            """)
        guard case .invalid(let reason) = result else {
            Issue.record("Expected .invalid, got \(result)")
            return
        }
        #expect(reason.contains("hyper"))
    }

    @Test func rejectsMissingApplication() throws {
        let result = try load("""
            { "hotkeys": [ { "key": "a", "modifiers": ["cmd"] } ] }
            """)
        guard case .invalid(let reason) = result else {
            Issue.record("Expected .invalid, got \(result)")
            return
        }
        #expect(reason.contains("application"))
    }

    @Test func rejectsMalformedJSON() throws {
        let result = try load("{ broken")
        guard case .invalid = result else {
            Issue.record("Expected .invalid, got \(result)")
            return
        }
    }

    @Test func reportsMissingFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hkd-test-does-not-exist.json")
        guard case .missing = ConfigLoader.load(from: url) else {
            Issue.record("Expected .missing")
            return
        }
    }
}

@Suite("Key and modifier mapping")
struct KeyMappingTests {
    @Test func mapsLettersCaseInsensitively() {
        #expect(KeyName.keyCode(for: "a") == CGKeyCode(kVK_ANSI_A))
        #expect(KeyName.keyCode(for: "A") == CGKeyCode(kVK_ANSI_A))
        #expect(KeyName.keyCode(for: "F11") == CGKeyCode(kVK_F11))
    }

    @Test func supportsAliases() {
        #expect(KeyName.keyCode(for: "enter") == KeyName.keyCode(for: "return"))
        #expect(KeyName.keyCode(for: "esc") == KeyName.keyCode(for: "escape"))
        #expect(KeyName.keyCode(for: "backspace") == KeyName.keyCode(for: "delete"))
    }

    @Test func rejectsUnknownKeys() {
        #expect(KeyName.keyCode(for: "f19") == nil)
        #expect(KeyName.keyCode(for: "") == nil)
        #expect(KeyName.keyCode(for: "keypad5") == nil)
    }

    @Test func parsesModifierAliases() {
        #expect(Modifier("cmd") == .command)
        #expect(Modifier("Command") == .command)
        #expect(Modifier("alt") == .option)
        #expect(Modifier("opt") == .option)
        #expect(Modifier("option") == .option)
        #expect(Modifier("ctrl") == .control)
        #expect(Modifier("control") == .control)
        #expect(Modifier("shift") == .shift)
        #expect(Modifier("hyper") == nil)
    }

    @Test func convertsToEventFlags() {
        let hotkey = Hotkey(keyCode: CGKeyCode(kVK_ANSI_T), modifiers: [.command, .option])
        #expect(hotkey.cgFlags == [.maskCommand, .maskAlternate])
        #expect(hotkey.carbonFlags == UInt32(cmdKey | optionKey))
    }

    @Test func emptyModifiersConvertToEmptyFlags() {
        let hotkey = Hotkey(keyCode: CGKeyCode(kVK_Space), modifiers: [])
        #expect(hotkey.cgFlags == [])
        #expect(hotkey.carbonFlags == 0)
    }
}

@Suite("Backend selection")
struct BackendSelectionTests {
    private func binding(key: Int, modifiers: Set<Modifier>) -> Binding {
        Binding(
            hotkey: Hotkey(keyCode: CGKeyCode(key), modifiers: modifiers),
            application: "Test",
            name: "test"
        )
    }

    @Test func prefersCarbonWhenAllHotkeysHaveModifiers() {
        let bindings = [
            binding(key: kVK_ANSI_A, modifiers: [.command]),
            binding(key: kVK_ANSI_B, modifiers: [.control, .option]),
        ]
        #expect(HotkeyBackendKind.required(for: bindings) == .carbon)
    }

    @Test func requiresEventTapForModifierlessHotkeys() {
        let bindings = [
            binding(key: kVK_ANSI_A, modifiers: [.command]),
            binding(key: kVK_F5, modifiers: []),
        ]
        #expect(HotkeyBackendKind.required(for: bindings) == .eventTap)
    }

    @Test func prefersCarbonForEmptyConfig() {
        #expect(HotkeyBackendKind.required(for: []) == .carbon)
    }
}

@Suite("Deduplication")
struct DeduplicationTests {
    private func binding(key: Int, application: String) -> Binding {
        Binding(
            hotkey: Hotkey(keyCode: CGKeyCode(key), modifiers: [.command]),
            application: application,
            name: "command+test"
        )
    }

    @Test func lastDefinitionWins() {
        let bindings = [
            binding(key: kVK_ANSI_A, application: "First"),
            binding(key: kVK_ANSI_B, application: "Other"),
            binding(key: kVK_ANSI_A, application: "Second"),
        ]
        let result = Daemon.deduplicated(bindings)
        #expect(result.count == 2)
        #expect(result[0].application == "Second")
        #expect(result[1].application == "Other")
    }

    @Test func keepsDistinctBindings() {
        let bindings = [
            binding(key: kVK_ANSI_A, application: "One"),
            binding(key: kVK_ANSI_B, application: "Two"),
        ]
        #expect(Daemon.deduplicated(bindings) == bindings)
    }
}
