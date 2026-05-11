import Foundation

enum SpaceSelection {
    /// Returns the id that should be kept selected after the spaces list changes.
    /// Keeps the current selection when it is still present; otherwise falls back
    /// to the first available space, or nil when the list is empty.
    static func resolve(spaces: [Space], current: String?) -> String? {
        if let current, spaces.contains(where: { $0.id == current }) {
            return current
        }
        return spaces.first?.id
    }
}
