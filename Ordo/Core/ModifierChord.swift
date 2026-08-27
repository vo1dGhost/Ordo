import CoreGraphics
import Foundation

/// 仅包含 Ordo 支持的四种修饰键。
struct ModifierChord: OptionSet, Hashable, Codable, Sendable {
    let rawValue: UInt8

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    static let command = ModifierChord(rawValue: 1 << 0)
    static let option = ModifierChord(rawValue: 1 << 1)
    static let control = ModifierChord(rawValue: 1 << 2)
    static let shift = ModifierChord(rawValue: 1 << 3)

    static let allModifiers: [ModifierChord] = [
        .command,
        .option,
        .control,
        .shift,
    ]

    static let defaultResize: ModifierChord = [.option, .shift]
    static let defaultSnap: ModifierChord = [.command, .control]
    static let defaultMove: ModifierChord = [.control, .shift]

    private static let supportedRawValue = allModifiers.reduce(UInt8.zero) {
        $0 | $1.rawValue
    }

    /// 从系统事件标志中提取 Ordo 关心的修饰键；Caps Lock、Fn 等标志会被忽略。
    init(eventFlags: CGEventFlags) {
        var chord: ModifierChord = []
        if eventFlags.contains(.maskCommand) {
            chord.insert(.command)
        }
        if eventFlags.contains(.maskAlternate) {
            chord.insert(.option)
        }
        if eventFlags.contains(.maskControl) {
            chord.insert(.control)
        }
        if eventFlags.contains(.maskShift) {
            chord.insert(.shift)
        }
        self = chord
    }

    init(cgEventFlags: CGEventFlags) {
        self.init(eventFlags: cgEventFlags)
    }

    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.command) {
            flags.insert(.maskCommand)
        }
        if contains(.option) {
            flags.insert(.maskAlternate)
        }
        if contains(.control) {
            flags.insert(.maskControl)
        }
        if contains(.shift) {
            flags.insert(.maskShift)
        }
        return flags
    }

    var modifierCount: Int {
        Int(rawValue.nonzeroBitCount)
    }

    var containsOnlySupportedModifiers: Bool {
        rawValue & ~Self.supportedRawValue == 0
    }

    var isValid: Bool {
        containsOnlySupportedModifiers && modifierCount >= 2
    }

    /// 使用固定顺序，确保设置界面及菜单栏展示稳定。
    var displayString: String {
        let symbols: [(ModifierChord, String)] = [
            (.command, "⌘"),
            (.option, "⌥"),
            (.control, "⌃"),
            (.shift, "⇧"),
        ]
        return symbols.compactMap { contains($0.0) ? $0.1 : nil }.joined()
    }

    func validate() throws {
        guard containsOnlySupportedModifiers else {
            throw ModifierChordValidationError.unsupportedModifiers(self)
        }
        guard modifierCount >= 2 else {
            throw ModifierChordValidationError.tooFewModifiers(self)
        }
    }

    static func validateUnique(_ chords: [ModifierChord]) throws {
        var seen = Set<ModifierChord>()
        for chord in chords {
            try chord.validate()
            guard seen.insert(chord).inserted else {
                throw ModifierChordValidationError.duplicateChord(chord)
            }
        }
    }

    static func defaultChord(for mode: InteractionMode) -> ModifierChord {
        switch mode {
        case .resize:
            .defaultResize
        case .snap:
            .defaultSnap
        case .move:
            .defaultMove
        }
    }
}

enum ModifierChordValidationError: Error, Equatable, Sendable {
    case tooFewModifiers(ModifierChord)
    case unsupportedModifiers(ModifierChord)
    case duplicateChord(ModifierChord)
}
