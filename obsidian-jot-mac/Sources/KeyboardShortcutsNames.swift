import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleJotPanel = Self(
        "toggleJotPanel",
        default: .init(.j, modifiers: [.control, .shift])
    )
}
