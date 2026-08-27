import CoreGraphics
import XCTest
@testable import Ordo

final class CoreLayoutEngineTests: XCTestCase {
    private let visibleFrame = CGRect(x: -100, y: 40, width: 1001, height: 801)

    func testAllEightLayoutsInQuartzCoordinates() throws {
        let expected: [SnapLayout: CGRect] = [
            .topLeft: CGRect(x: -100, y: 40, width: 500.5, height: 400.5),
            .top: visibleFrame,
            .topRight: CGRect(x: 400.5, y: 40, width: 500.5, height: 400.5),
            .right: CGRect(x: 400.5, y: 40, width: 500.5, height: 801),
            .bottomRight: CGRect(x: 400.5, y: 440.5, width: 500.5, height: 400.5),
            .bottom: CGRect(x: 100.2, y: 200.2, width: 600.6, height: 480.6),
            .bottomLeft: CGRect(x: -100, y: 440.5, width: 500.5, height: 400.5),
            .left: CGRect(x: -100, y: 40, width: 500.5, height: 801),
        ]

        for layout in SnapLayout.allCases {
            assertRect(
                LayoutEngine.targetFrame(for: layout, in: visibleFrame),
                equals: try XCTUnwrap(expected[layout]),
                message: layout.rawValue
            )
        }
    }

    func testVisibleFrameOffsetsArePreserved() {
        let dockAdjustedFrame = CGRect(x: 80, y: 23, width: 1360, height: 827)

        XCTAssertEqual(
            LayoutEngine.targetFrame(for: .top, in: dockAdjustedFrame),
            dockAdjustedFrame
        )
        XCTAssertEqual(
            LayoutEngine.targetFrame(for: .left, in: dockAdjustedFrame),
            CGRect(x: 80, y: 23, width: 680, height: 827)
        )
    }

    func testAppKitToQuartzConversionForScreensInEveryDirection() {
        let main = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let screens: [(CGRect, CGRect)] = [
            (main, CGRect(x: 0, y: 0, width: 1440, height: 900)),
            (
                CGRect(x: -1280, y: 0, width: 1280, height: 800),
                CGRect(x: -1280, y: 100, width: 1280, height: 800)
            ),
            (
                CGRect(x: 1440, y: 0, width: 1920, height: 1080),
                CGRect(x: 1440, y: -180, width: 1920, height: 1080)
            ),
            (
                CGRect(x: 0, y: 900, width: 1920, height: 1080),
                CGRect(x: 0, y: -1080, width: 1920, height: 1080)
            ),
            (
                CGRect(x: 0, y: -1080, width: 1920, height: 1080),
                CGRect(x: 0, y: 900, width: 1920, height: 1080)
            ),
        ]

        for (appKitFrame, expectedQuartzFrame) in screens {
            let quartzFrame = ScreenCoordinateConverter.appKitToQuartz(
                appKitFrame,
                mainScreenFrame: main
            )
            XCTAssertEqual(quartzFrame, expectedQuartzFrame)
            XCTAssertEqual(
                ScreenCoordinateConverter.quartzToAppKit(
                    quartzFrame,
                    mainScreenFrame: main
                ),
                appKitFrame
            )
        }
    }

    func testCoordinateConversionUsesLogicalPointsIndependentOfBackingScale() {
        let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let appKitVisibleFrame = CGRect(x: 0.5, y: 37.5, width: 1511, height: 909)
        let expected = CGRect(x: 0.5, y: 35.5, width: 1511, height: 909)

        XCTAssertEqual(
            ScreenCoordinateConverter.appKitToQuartz(
                appKitVisibleFrame,
                mainScreenFrame: main
            ),
            expected
        )
    }

    private func assertRect(
        _ actual: CGRect,
        equals expected: CGRect,
        accuracy: CGFloat = 0.0001,
        message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.origin.x, expected.origin.x, accuracy: accuracy, message, file: file, line: line)
        XCTAssertEqual(actual.origin.y, expected.origin.y, accuracy: accuracy, message, file: file, line: line)
        XCTAssertEqual(actual.size.width, expected.size.width, accuracy: accuracy, message, file: file, line: line)
        XCTAssertEqual(actual.size.height, expected.size.height, accuracy: accuracy, message, file: file, line: line)
    }
}
