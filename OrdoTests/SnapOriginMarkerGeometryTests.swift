import CoreGraphics
import XCTest
@testable import Ordo

final class SnapOriginMarkerGeometryTests: XCTestCase {
    func testEachLayoutOccupiesItsOwnScreenDirection() {
        let rect = CGRect(x: 0, y: 0, width: 40, height: 40)
        let directionPoints: [(SnapLayout, CGPoint)] = [
            (.top, CGPoint(x: 20, y: 7.5)),
            (.topRight, CGPoint(x: 28.8, y: 11.2)),
            (.right, CGPoint(x: 32.5, y: 20)),
            (.bottomRight, CGPoint(x: 28.8, y: 28.8)),
            (.bottom, CGPoint(x: 20, y: 32.5)),
            (.bottomLeft, CGPoint(x: 11.2, y: 28.8)),
            (.left, CGPoint(x: 7.5, y: 20)),
            (.topLeft, CGPoint(x: 11.2, y: 11.2))
        ]

        for (expectedLayout, point) in directionPoints {
            let matchingLayouts = SnapLayout.allCases.filter {
                SnapOriginMarkerFacet(layout: $0).path(in: rect).contains(point)
            }
            XCTAssertEqual(matchingLayouts, [expectedLayout])
        }
    }

    func testFacetsLeaveEmptyCenterAndGapsInsideCanvas() {
        let rect = CGRect(x: 0, y: 0, width: 40, height: 40)
        let safeBounds = rect.insetBy(dx: 3, dy: 3)
        let emptyCenter = CGRect(x: 16, y: 16, width: 8, height: 8)

        for layout in SnapLayout.allCases {
            let path = SnapOriginMarkerFacet(layout: layout).path(in: rect)
            XCTAssertTrue(safeBounds.contains(path.boundingRect))
            XCTAssertFalse(path.boundingRect.intersects(emptyCenter))

            for gapIndex in 0..<8 {
                let angle = (CGFloat(gapIndex) + 0.5) * .pi / 4
                let gap = CGPoint(x: 20 + cos(angle) * 12.5, y: 20 + sin(angle) * 12.5)
                XCTAssertFalse(path.contains(gap))
            }
        }
    }
}
