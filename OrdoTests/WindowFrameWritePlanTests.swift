import XCTest
@testable import Ordo

final class WindowFrameWritePlanTests: XCTestCase {
    func testIntermediatePlanWritesSizeThenPosition() {
        XCTAssertEqual(WindowFrameWritePlan.intermediate.steps, [.size, .position])
    }

    func testExactPlanRepeatsSizeAfterPosition() {
        XCTAssertEqual(WindowFrameWritePlan.exact.steps, [.size, .position, .size])
    }
}
