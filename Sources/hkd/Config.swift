import Foundation

/// The set of hotkey bindings declared in the user's config file.
struct Config: Equatable {
    let bindings: [Binding]

    static let empty = Config(bindings: [])
}

/// One entry from the config file: a hotkey mapped to an application.
struct Binding: Equatable {
    let hotkey: Hotkey
    let application: String
    /// Human-readable form, e.g. "cmd+shift+b".
    let name: String
}

extension Config: Decodable {
    private enum CodingKeys: String, CodingKey {
        case hotkeys
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bindings = try container.decode([Binding].self, forKey: .hotkeys)
    }
}

extension Binding: Decodable {
    private enum CodingKeys: String, CodingKey {
        case key, modifiers, application
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let keyToken = try container.decode(String.self, forKey: .key)
        guard let keyCode = KeyName.keyCode(for: keyToken) else {
            throw DecodingError.dataCorruptedError(
                forKey: .key, in: container,
                debugDescription: "Unknown key \"\(keyToken)\""
            )
        }

        let modifierTokens = try container.decodeIfPresent([String].self, forKey: .modifiers) ?? []
        var modifiers = Set<Modifier>()
        for token in modifierTokens {
            guard let modifier = Modifier(token) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .modifiers, in: container,
                    debugDescription: "Unknown modifier \"\(token)\""
                )
            }
            modifiers.insert(modifier)
        }

        hotkey = Hotkey(keyCode: keyCode, modifiers: modifiers)
        application = try container.decode(String.self, forKey: .application)
        name = (Modifier.canonicalOrder.filter(modifiers.contains).map(\.rawValue)
            + [keyToken.lowercased()]).joined(separator: "+")
    }
}

/// Loads and validates the config file.
enum ConfigLoader {
    enum LoadResult {
        case loaded(Config)
        case missing
        case invalid(String)
    }

    static func load(from url: URL) -> LoadResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return .missing
        } catch {
            return .invalid(error.localizedDescription)
        }

        do {
            return .loaded(try JSONDecoder().decode(Config.self, from: data))
        } catch let error as DecodingError {
            return .invalid(describe(error))
        } catch {
            return .invalid(error.localizedDescription)
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .dataCorrupted(let context):
            if let underlying = context.underlyingError as NSError?,
               let detail = underlying.userInfo[NSDebugDescriptionErrorKey] as? String {
                return detail
            }
            return context.debugDescription
        case .keyNotFound(let key, _):
            return "Missing required field \"\(key.stringValue)\""
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return context.debugDescription
        @unknown default:
            return String(describing: error)
        }
    }
}
