import AppKit
import SwiftUI
import XCTest
@testable import Ordo

@MainActor
final class SnapOriginMarkerRenderingTests: XCTestCase {
    func testOpaqueArtworkKeepsTransparentCanvasEdgesAndEmptyCenterAtBothScales() throws {
        for scale in [1, 2] {
            for layout in [nil] + SnapLayout.allCases.map(Optional.some) {
                let bitmap = try render(layout: layout, scale: scale)
                XCTAssertEqual(bitmap.pixelsWide, 40 * scale)
                XCTAssertEqual(bitmap.pixelsHigh, 40 * scale)
                let last = 40 * scale - 1
                let middle = 20 * scale
                for point in [(0, 0), (last, last), (middle, 0), (middle, last), (0, middle), (last, middle)] {
                    let color = try XCTUnwrap(bitmap.colorAt(x: point.0, y: point.1))
                    XCTAssertLessThan(color.alphaComponent, 0.04)
                }
                var maximumCenterAlpha: CGFloat = 0
                for x in (16 * scale)..<(24 * scale) {
                    for y in (16 * scale)..<(24 * scale) {
                        let center = try XCTUnwrap(bitmap.colorAt(x: x, y: y))
                        maximumCenterAlpha = max(maximumCenterAlpha, center.alphaComponent)
                    }
                }
                XCTAssertLessThan(maximumCenterAlpha, 0.04)
            }
        }
    }

    func testOpaqueHighlightOnlyChangesSelectedFacet() throws {
        let neutral = try render(layout: nil, scale: 2)
        let points: [(SnapLayout, Int, Int)] = [
            (.top, 40, 15), (.topRight, 58, 22), (.right, 65, 40),
            (.bottomRight, 58, 58), (.bottom, 40, 65),
            (.bottomLeft, 22, 58), (.left, 15, 40), (.topLeft, 22, 22)
        ]

        for selected in SnapLayout.allCases {
            let bitmap = try render(layout: selected, scale: 2)
            for (layout, x, y) in points {
                let before = try XCTUnwrap(neutral.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                let after = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                let difference = abs(before.redComponent - after.redComponent)
                    + abs(before.greenComponent - after.greenComponent)
                    + abs(before.blueComponent - after.blueComponent)
                if layout == selected {
                    XCTAssertGreaterThan(difference, 0.2)
                } else {
                    XCTAssertLessThan(difference, 0.03)
                }
            }
        }
    }

    private func render(layout: SnapLayout?, scale: Int) throws -> NSBitmapImageRep {
        // ImageRenderer 不能作为系统玻璃截图；这里只核验确定性的不透明回退。
        let renderer = ImageRenderer(content: SnapOriginMarkerArtwork(
            selectedLayout: layout,
            reduceMotion: true,
            reduceTransparency: true
        ))
        renderer.scale = CGFloat(scale)
        return NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
    }
}
