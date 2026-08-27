import CoreGraphics
import XCTest
@testable import Ordo

final class CoreRadialGestureClassifierTests: XCTestCase {
    private let origin = CGPoint(x: 200, y: 200)

    func testEightDirectionsMapToClockwiseLayouts() {
        let vectors: [(CGVector, SnapLayout)] = [
            (CGVector(dx: -100, dy: -100), .topLeft),
            (CGVector(dx: 0, dy: -100), .top),
            (CGVector(dx: 100, dy: -100), .topRight),
            (CGVector(dx: 100, dy: 0), .right),
            (CGVector(dx: 100, dy: 100), .bottomRight),
            (CGVector(dx: 0, dy: 100), .bottom),
            (CGVector(dx: -100, dy: 100), .bottomLeft),
            (CGVector(dx: -100, dy: 0), .left),
        ]

        for (vector, expected) in vectors {
            var classifier = RadialGestureClassifier()
            let location = CGPoint(x: origin.x + vector.dx, y: origin.y + vector.dy)
            XCTAssertEqual(classifier.update(from: origin, to: location), expected)
        }
    }

    func testEntryAndExitDeadZones() {
        var classifier = RadialGestureClassifier()

        XCTAssertNil(
            classifier.update(
                from: origin,
                to: CGPoint(x: origin.x + 23.999, y: origin.y)
            )
        )
        XCTAssertNil(
            classifier.update(
                from: origin,
                to: CGPoint(x: origin.x + 24, y: origin.y)
            )
        )
        XCTAssertEqual(
            classifier.update(
                from: origin,
                to: CGPoint(x: origin.x + 24.001, y: origin.y)
            ),
            .right
        )
        XCTAssertEqual(
            classifier.update(
                from: origin,
                to: CGPoint(x: origin.x + 17, y: origin.y)
            ),
            .right
        )
        XCTAssertNil(
            classifier.update(
                from: origin,
                to: CGPoint(x: origin.x + 16, y: origin.y)
            )
        )
        XCTAssertNil(
            classifier.update(
                from: origin,
                to: CGPoint(x: origin.x + 20, y: origin.y)
            )
        )
    }

    func testAngularHysteresisPreventsBoundaryFlicker() {
        var classifier = RadialGestureClassifier()
        XCTAssertEqual(classifier.update(from: origin, to: point(radius: 100, degrees: 0)), .right)

        XCTAssertEqual(
            classifier.update(from: origin, to: point(radius: 100, degrees: 27)),
            .right
        )
        XCTAssertEqual(
            classifier.update(from: origin, to: point(radius: 100, degrees: 30)),
            .bottomRight
        )
        XCTAssertEqual(
            classifier.update(from: origin, to: point(radius: 100, degrees: 18)),
            .bottomRight
        )
        XCTAssertEqual(
            classifier.update(from: origin, to: point(radius: 100, degrees: 14)),
            .right
        )
    }

    func testResetRemovesSelection() {
        var classifier = RadialGestureClassifier()
        XCTAssertEqual(classifier.update(from: origin, to: point(radius: 100, degrees: 90)), .bottom)

        classifier.reset()

        XCTAssertNil(classifier.currentLayout)
    }

    private func point(radius: CGFloat, degrees: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: origin.x + cos(radians) * radius,
            y: origin.y + sin(radians) * radius
        )
    }
}
