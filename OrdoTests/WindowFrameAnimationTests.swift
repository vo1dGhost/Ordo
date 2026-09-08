import CoreGraphics
import XCTest
@testable import Ordo

final class WindowFrameAnimationTests: XCTestCase {
    private let animation = WindowFrameAnimation.snapDefault

    func testSnapDefaultUsesExpectedTiming() {
        XCTAssertEqual(animation.duration, .milliseconds(200))
        XCTAssertEqual(animation.frameInterval, .nanoseconds(16_666_667))
        XCTAssertEqual(WindowFrameTransition.animated(animation), .animated(.snapDefault))
    }

    func testInterpolationReturnsExactEndpointsAndClampsProgress() {
        let start = CGRect(x: 40, y: 80, width: 320, height: 240)
        let end = CGRect(x: 800, y: 120, width: 640, height: 700)

        XCTAssertEqual(animation.interpolatedFrame(from: start, to: end, progress: -1), start)
        XCTAssertEqual(animation.interpolatedFrame(from: start, to: end, progress: 0), start)
        XCTAssertEqual(animation.interpolatedFrame(from: start, to: end, progress: 1), end)
        XCTAssertEqual(animation.interpolatedFrame(from: start, to: end, progress: 2), end)
    }

    func testMidpointUsesSmoothstepForPositionAndSize() {
        let start = CGRect(x: 0, y: 100, width: 200, height: 400)
        let end = CGRect(x: 800, y: 500, width: 600, height: 800)

        let frame = animation.interpolatedFrame(from: start, to: end, progress: 0.5)

        assertRect(
            frame,
            equals: CGRect(x: 400, y: 300, width: 400, height: 600)
        )
    }

    func testFirstSixtyHertzSampleMovesAboutTwoPercent() {
        let frame = animation.interpolatedFrame(
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 100, y: 100, width: 200, height: 200),
            progress: 16_666_667.0 / 200_000_000.0
        )

        XCTAssertEqual(frame.origin.x, 1.96759267, accuracy: 0.000001)
        XCTAssertEqual(frame.origin.y, 1.96759267, accuracy: 0.000001)
        XCTAssertEqual(frame.width, 101.96759267, accuracy: 0.000001)
        XCTAssertEqual(frame.height, 101.96759267, accuracy: 0.000001)
    }

    func testInterpolationSupportsNegativeMultiScreenCoordinates() {
        let start = CGRect(x: -1_280, y: 100, width: 1_280, height: 800)
        let end = CGRect(x: 1_440, y: -180, width: 960, height: 540)

        let frame = animation.interpolatedFrame(from: start, to: end, progress: 0.5)

        assertRect(
            frame,
            equals: CGRect(x: 80, y: -40, width: 1_120, height: 670)
        )
    }

    func testNextSampleDeadlineUsesAbsoluteTimeGridForDifferentWriteDurations() {
        XCTAssertEqual(
            animation.nextSampleDeadline(after: .zero),
            .nanoseconds(16_666_667)
        )
        XCTAssertEqual(
            animation.nextSampleDeadline(after: .milliseconds(5)),
            .nanoseconds(16_666_667)
        )
        XCTAssertEqual(
            animation.nextSampleDeadline(after: .nanoseconds(16_666_667)),
            .nanoseconds(33_333_334)
        )
        XCTAssertEqual(
            animation.nextSampleDeadline(after: .milliseconds(20)),
            .nanoseconds(33_333_334)
        )
        XCTAssertEqual(
            animation.nextSampleDeadline(after: .milliseconds(40)),
            .nanoseconds(50_000_001)
        )
    }

    func testNextSampleDeadlineSkipsExpiredFramesWithoutCatchingUp() {
        XCTAssertEqual(
            animation.nextSampleDeadline(after: .milliseconds(40)),
            .nanoseconds(50_000_001)
        )
        XCTAssertEqual(
            animation.nextSampleDeadline(after: .milliseconds(120)),
            .nanoseconds(133_333_336)
        )
    }

    func testNextSampleDeadlineIsStrictlyAfterExactGridPoint() {
        XCTAssertEqual(
            animation.nextSampleDeadline(after: .nanoseconds(16_666_667)),
            .nanoseconds(33_333_334)
        )
    }

    func testNextSampleDeadlineDoesNotReturnAnimationEndpoint() {
        XCTAssertEqual(
            animation.nextSampleDeadline(after: .nanoseconds(183_333_336)),
            .nanoseconds(183_333_337)
        )
        XCTAssertNil(animation.nextSampleDeadline(after: .nanoseconds(183_333_337)))
        XCTAssertNil(animation.nextSampleDeadline(after: .milliseconds(199)))
        XCTAssertNil(animation.nextSampleDeadline(after: .milliseconds(200)))
    }

    func testInterpolationIsMonotonicAndNeverOvershoots() {
        let start = CGRect(x: -500, y: 900, width: 1_200, height: 300)
        let end = CGRect(x: 700, y: -300, width: 400, height: 900)
        var previous = start

        for step in 1...100 {
            let frame = animation.interpolatedFrame(
                from: start,
                to: end,
                progress: Double(step) / 100
            )

            XCTAssertGreaterThanOrEqual(frame.origin.x, previous.origin.x)
            XCTAssertLessThanOrEqual(frame.origin.y, previous.origin.y)
            XCTAssertLessThanOrEqual(frame.width, previous.width)
            XCTAssertGreaterThanOrEqual(frame.height, previous.height)

            assertValue(frame.origin.x, liesBetween: start.origin.x, and: end.origin.x)
            assertValue(frame.origin.y, liesBetween: start.origin.y, and: end.origin.y)
            assertValue(frame.width, liesBetween: start.width, and: end.width)
            assertValue(frame.height, liesBetween: start.height, and: end.height)

            previous = frame
        }

        XCTAssertEqual(previous, end)
    }

    private func assertRect(
        _ actual: CGRect,
        equals expected: CGRect,
        accuracy: CGFloat = 0.0001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.origin.x, expected.origin.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.origin.y, expected.origin.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: accuracy, file: file, line: line)
    }

    private func assertValue(
        _ value: CGFloat,
        liesBetween first: CGFloat,
        and second: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(value, min(first, second), file: file, line: line)
        XCTAssertLessThanOrEqual(value, max(first, second), file: file, line: line)
    }
}
