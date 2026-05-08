import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openQuickNote = Self(
        "openQuickNote",
        default: .init(.c, modifiers: [.command, .shift, .option])
    )
}
