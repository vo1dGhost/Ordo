import CoreGraphics
import XCTest
@testable import Ordo

final class CoreModifierChordTests: XCTestCase {
    func testDefaultChordsAndDisplayOrder() {
        XCTAssertEqual(ModifierChord.defaultResize, [.option, .shift])
        XCTAssertEqual(ModifierChord.defaultSnap, [.command, .control])
        XCTAssertEqual(ModifierChord.defaultMove, [.control, .shift])

        XCTAssertEqual(ModifierChord.defaultResize.displayString, "⌥⇧")
        XCTAssertEqual(ModifierChord.defaultSnap.displayString, "⌘⌃")
        XCTAssertEqual(ModifierChord.defaultMove.displayString, "⌃⇧")
        XCTAssertEqual(
            ModifierChord.defaultChord(for: .resize),
            ModifierChord.defaultResize
        )
    }

    func testValidityRequiresTwoSupportedModifiers() {
        XCTAssertFalse(ModifierChord().isValid)
        XCTAssertFalse(ModifierChord.command.isValid)
        XCTAssertTrue(ModifierChord([.command, .option]).isValid)

        let unsupported = ModifierChord(rawValue: 1 << 7)
        XCTAssertFalse(unsupported.containsOnlySupportedModifiers)
        XCTAssertFalse(unsupported.isValid)
        XCTAssertThrowsError(try unsupported.validate()) { error in
            XCTAssertEqual(
                error as? ModifierChordValidationError,
                .unsupportedModifiers(unsupported)
            )
        }
    }

    func testUniqueValidationRejectsConflicts() throws {
        XCTAssertNoThrow(
            try ModifierChord.validateUnique([
                .defaultResize,
                .defaultSnap,
                .defaultMove,
            ])
        )

        XCTAssertThrowsError(
            try ModifierChord.validateUnique([.defaultResize, .defaultResize])
        ) { error in
            XCTAssertEqual(
                error as? ModifierChordValidationError,
                .duplicateChord(.defaultResize)
            )
        }

        XCTAssertThrowsError(try ModifierChord.control.validate()) { error in
            XCTAssertEqual(
                error as? ModifierChordValidationError,
                .tooFewModifiers(.control)
            )
        }
    }

    func testCGEventFlagsConversionIgnoresCapsLockAndFunction() {
        let flags: CGEventFlags = [
            .maskCommand,
            .maskShift,
            .maskAlphaShift,
            .maskSecondaryFn,
        ]

        let chord = ModifierChord(eventFlags: flags)
        XCTAssertEqual(chord, [.command, .shift])
        XCTAssertEqual(chord.cgEventFlags, [.maskCommand, .maskShift])
        XCTAssertEqual(ModifierChord(cgEventFlags: chord.cgEventFlags), chord)
    }
}
