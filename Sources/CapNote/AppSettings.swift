import AppKit
import Foundation
import Observation

enum WindowPosition: String, CaseIterable, Identifiable {
    case lastUsed
    case centered
    case atCursor

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .lastUsed: return "Where I left it"
        case .centered: return "Centered on screen"
        case .atCursor: return "At cursor position"
        }
    }
}

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var selectedSpaceId: String? {
        didSet { defaults.set(selectedSpaceId, forKey: Keys.selectedSpaceId) }
    }

    var windowPosition: WindowPosition {
        didSet { defaults.set(windowPosition.rawValue, forKey: Keys.windowPosition) }
    }

    var useSeparator: Bool {
        didSet { defaults.set(useSeparator, forKey: Keys.useSeparator) }
    }

    var separatorString: String {
        didSet { defaults.set(separatorString, forKey: Keys.separatorString) }
    }

    var includeTimestamp: Bool {
        didSet { defaults.set(includeTimestamp, forKey: Keys.includeTimestamp) }
    }

    var savedWindowOrigin: NSPoint? {
        didSet {
            if let origin = savedWindowOrigin {
                defaults.set(NSStringFromPoint(origin), forKey: Keys.savedWindowOrigin)
            } else {
                defaults.removeObject(forKey: Keys.savedWindowOrigin)
            }
        }
    }

    /// Reads the API token from the macOS Keychain. Returns `nil` when not set.
    /// Token writes go through `setApiToken(_:)` so callers can react to errors.
    var apiToken: String? {
        Keychain.shared.read()
    }

    func setApiToken(_ value: String?) throws {
        if let value, !value.isEmpty {
            try Keychain.shared.save(value)
        } else {
            try Keychain.shared.delete()
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedSpaceId = defaults.string(forKey: Keys.selectedSpaceId)
        windowPosition = WindowPosition(rawValue: defaults.string(forKey: Keys.windowPosition) ?? "")
            ?? .lastUsed
        useSeparator = defaults.object(forKey: Keys.useSeparator) as? Bool ?? true
        separatorString = defaults.string(forKey: Keys.separatorString) ?? "---\n\n"
        includeTimestamp = defaults.object(forKey: Keys.includeTimestamp) as? Bool ?? false

        if let originString = defaults.string(forKey: Keys.savedWindowOrigin),
           !originString.isEmpty {
            let parsed = NSPointFromString(originString)
            savedWindowOrigin = (parsed == .zero) ? nil : parsed
        } else {
            savedWindowOrigin = nil
        }
    }

    private enum Keys {
        static let selectedSpaceId = "selectedSpaceId"
        static let windowPosition = "windowPosition"
        static let useSeparator = "useSeparator"
        static let separatorString = "separatorString"
        static let includeTimestamp = "includeTimestamp"
        static let savedWindowOrigin = "savedWindowOrigin"
    }
}
