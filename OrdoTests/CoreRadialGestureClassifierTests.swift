import CoreGraphics
import XCTest
@testable import Ordo

final class CoreRadialGestureClassifierTests: XCTestCase {
    private let origin = CGPoint(x: 200, y: 200)

    func testFixedDefaultDistanceUsesEightPointsAndProportionalExit() {
        var classifier = RadialGestureClassifier()
        XCTAssertEqual(classifier.entryRadius, 8)
        XCTAssertEqual(classifier.exitRadius, 16.0 / 3.0, accuracy: 0.000_001)
        XCTAssertNil(classifier.update(from: .zero, to: CGPoint(x: 8, y: 0)))
        XCTAssertEqual(classifier.update(from: .zero, to: CGPoint(x: 8.001, y: 0)), .right)
        XCTAssertEqual(classifier.update(from: .zero, to: CGPoint(x: 16.0 / 3.0 + 0.001, y: 0)), .right)
        XCTAssertNil(classifier.update(from: .zero, to: CGPoint(x: 16.0 / 3.0, y: 0)))
    }

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
                to: CGPoint(x: origin.x + 7.999, y: origin.y)
            )
        )
        XCTAssertNil(
            classifier.update(
                from: origin,
                to: CGPoint(x: origin.x + 8, y: origin.y)
            )
        )
        XCTAssertEqual(
            classifier.update(
                from: origin,
                to: CGPoint(x: origin.x + 8.001, y: origin.y)
            ),
            .right
        )
        XCTAssertEqual(
            classifier.update(
                from: origin,
                to: CGPoint(x: origin.x + 6, y: origin.y)
            ),
            .right
        )
        XCTAssertNil(
            classifier.update(
                from: origin,
                to: CGPoint(x: origin.x + 5, y: origin.y)
            )
        )
        XCTAssertNil(
            classifier.update(
                from: origin,
                to: CGPoint(x: origin.x + 7, y: origin.y)
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

    func testCustomDistancesPreserveEightDirectionsAndProportionalCancellation() {
        let directions: [(CGFloat, SnapLayout)] = [
            (0, .right), (45, .bottomRight), (90, .bottom), (135, .bottomLeft),
            (180, .left), (225, .topLeft), (270, .top), (315, .topRight),
        ]
        for distance: CGFloat in [8, 24, 60, 200] {
            for (degrees, expected) in directions {
                var classifier = RadialGestureClassifier(entryRadius: distance, exitRadius: distance * 2 / 3)
                XCTAssertNil(classifier.update(from: origin, to: point(radius: distance - 0.01, degrees: degrees)))
                XCTAssertEqual(classifier.update(from: origin, to: point(radius: distance + 0.01, degrees: degrees)), expected)
                XCTAssertEqual(classifier.update(from: origin, to: point(radius: distance * 2 / 3 + 0.01, degrees: degrees)), expected)
                XCTAssertNil(classifier.update(from: origin, to: point(radius: distance * 2 / 3 - 0.01, degrees: degrees)))
            }
        }
    }

    private func point(radius: CGFloat, degrees: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: origin.x + cos(radians) * radius,
            y: origin.y + sin(radians) * radius
        )
    }
}
