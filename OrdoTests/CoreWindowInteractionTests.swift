import CoreGraphics
import XCTest
@testable import Ordo

final class CoreWindowInteractionTests: XCTestCase {
    func testRelativeMoveHasNoInitialJump() {
        let frame = CGRect(x: -300, y: 120, width: 640, height: 480)
        let start = CGPoint(x: 50, y: 80)

        XCTAssertEqual(
            WindowFrameCalculator.movedFrame(
                initialFrame: frame,
                from: start,
                to: start
            ),
            frame
        )
        XCTAssertEqual(
            WindowFrameCalculator.movedFrame(
                initialFrame: frame,
                from: start,
                to: CGPoint(x: 90, y: 60)
            ),
            CGRect(x: -260, y: 100, width: 640, height: 480)
        )
    }

    func testResizeKeepsTopLeftFixedAndClampsSize() {
        let frame = CGRect(x: 20, y: 30, width: 300, height: 200)
        let start = CGPoint(x: 100, y: 100)

        XCTAssertEqual(
            WindowFrameCalculator.resizedFrame(
                initialFrame: frame,
                from: start,
                to: start
            ),
            frame
        )
        XCTAssertEqual(
            WindowFrameCalculator.resizedFrame(
                initialFrame: frame,
                from: start,
                to: CGPoint(x: 150, y: 170)
            ),
            CGRect(x: 20, y: 30, width: 350, height: 270)
        )
        XCTAssertEqual(
            WindowFrameCalculator.resizedFrame(
                initialFrame: frame,
                from: start,
                to: CGPoint(x: -500, y: -500),
                minimumSize: CGSize(width: 80, height: 60)
            ),
            CGRect(x: 20, y: 30, width: 80, height: 60)
        )
        XCTAssertEqual(
            WindowFrameCalculator.resizedFrame(
                initialFrame: frame,
                from: start,
                to: CGPoint(x: 500, y: 500),
                maximumSize: CGSize(width: 420, height: 360)
            ),
            CGRect(x: 20, y: 30, width: 420, height: 360)
        )
    }

    func testGestureSessionLocksWindowAndActivatesOnlyBeyondFourPoints() {
        let window = WindowSnapshot(
            id: UUID(),
            frame: CGRect(x: 10, y: 20, width: 300, height: 200),
            pid: 42
        )
        var session = GestureSession(
            mode: .move,
            window: window,
            startMouseLocation: .zero
        )

        XCTAssertFalse(session.updateMouseLocation(CGPoint(x: 4, y: 0)))
        XCTAssertEqual(session.phase, .tracking)
        XCTAssertEqual(session.window, window)

        XCTAssertTrue(session.updateMouseLocation(CGPoint(x: 4.01, y: 0)))
        XCTAssertEqual(session.phase, .active)
        XCTAssertFalse(session.updateMouseLocation(CGPoint(x: 20, y: 20)))
        XCTAssertEqual(session.window.id, window.id)
    }

    func testSnapSessionReturnsSelectionOnceOnRelease() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 850)
        let window = WindowSnapshot(id: UUID(), frame: .zero, pid: 7)
        var session = GestureSession(
            mode: .snap,
            window: window,
            startMouseLocation: CGPoint(x: 500, y: 400),
            lockedVisibleFrame: visibleFrame
        )

        session.setSelectedLayout(.topRight)
        XCTAssertEqual(session.end(), .topRight)
        XCTAssertEqual(session.phase, .ended)
        XCTAssertNil(session.selectedLayout)
        XCTAssertNil(session.end())

        let lastLocation = session.latestMouseLocation
        XCTAssertFalse(session.updateMouseLocation(CGPoint(x: 900, y: 900)))
        XCTAssertEqual(session.latestMouseLocation, lastLocation)
        XCTAssertEqual(session.lockedVisibleFrame, visibleFrame)
    }

    func testCancelledSessionNeverCommitsLayout() {
        let window = WindowSnapshot(id: UUID(), frame: .zero, pid: 7)
        var session = GestureSession(
            mode: .snap,
            window: window,
            startMouseLocation: .zero
        )
        session.setSelectedLayout(.left)

        session.cancel()

        XCTAssertTrue(session.isEnded)
        XCTAssertNil(session.end())
    }
}
