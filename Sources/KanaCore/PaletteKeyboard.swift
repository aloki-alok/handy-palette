public struct PaletteKeyModifiers: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let command = PaletteKeyModifiers(rawValue: 1 << 0)
    public static let control = PaletteKeyModifiers(rawValue: 1 << 1)
    public static let option = PaletteKeyModifiers(rawValue: 1 << 2)
    public static let shift = PaletteKeyModifiers(rawValue: 1 << 3)
}

public enum PaletteKeyboardCommand: Equatable, Sendable {
    case moveSelection(Int)
    case activateSelection
    case dismiss
    case cycleSection(Int)
    case selectSection(Int)
    case newCustomItem
    case toggleFavorite
}

public enum PaletteKeyboardRouter {
    private static let sectionKeyCodes: [UInt16: Int] = [
        18: 0,
        19: 1,
        20: 2,
        21: 3,
        23: 4,
        22: 5,
        26: 6,
        28: 7,
        25: 8
    ]

    public static func command(keyCode: UInt16, characters: String?, modifiers: PaletteKeyModifiers) -> PaletteKeyboardCommand? {
        if keyCode == 53 { return .dismiss }
        if keyCode == 48, modifiers == .control || modifiers == [.control, .shift] {
            return .cycleSection(modifiers.contains(.shift) ? -1 : 1)
        }
        if modifiers.isEmpty {
            if keyCode == 125 { return .moveSelection(1) }
            if keyCode == 126 { return .moveSelection(-1) }
            if keyCode == 36 || keyCode == 76 { return .activateSelection }
        }
        if modifiers == .command, let index = sectionKeyCodes[keyCode] {
            return .selectSection(index)
        }
        if modifiers == .command, keyCode == 45 { return .newCustomItem }
        if modifiers == .command, keyCode == 2 { return .toggleFavorite }
        return nil
    }
}
