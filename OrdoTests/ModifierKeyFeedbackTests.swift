import SwiftUI
import XCTest
@testable import Ordo

final class ModifierKeyFeedbackTests: XCTestCase {
    func testPressingAndReleasingMultipleModifiersTracksOnlySupportedKeys() {
        var feedback = ModifierKeyFeedback()
        feedback.update([.shift, .control, .capsLock], isActive: true)
        XCTAssertEqual(feedback.pressedModifiers, [.shift, .control])
        feedback.update([.control], isActive: true)
        XCTAssertEqual(feedback.pressedModifiers, [.control])
        feedback.update([], isActive: true)
        XCTAssertEqual(feedback.pressedModifiers, [])
    }

    func testInactiveWindowAndLeavingPageClearHeldKeys() {
        var feedback = ModifierKeyFeedback()
        feedback.update([.command, .option], isActive: true)
        feedback.update([.command, .option], isActive: false)
        XCTAssertEqual(feedback.pressedModifiers, [])
        feedback.update([.shift], isActive: false)
        XCTAssertEqual(feedback.pressedModifiers, [])
        feedback.update([.shift], isActive: true)
        feedback.clear()
        XCTAssertEqual(feedback.pressedModifiers, [])
    }

    func testPressedKeyOverridesSelectedAndUnselectedStatesInEveryRow() {
        let selections: [ModifierChord] = [.defaultResize, .defaultSnap, .defaultMove]
        for selection in selections {
            for key in ModifierChord.allModifiers {
                XCTAssertEqual(ModifierKeyDisplayState(key: key, selection: selection, pressed: key), .pressed)
                XCTAssertEqual(
                    ModifierKeyDisplayState(key: key, selection: selection, pressed: []),
                    selection.contains(key) ? .selected : .idle
                )
            }
        }
    }
}
