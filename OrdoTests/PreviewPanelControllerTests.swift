import AppKit
import QuartzCore
import SwiftUI
import XCTest
@testable import Ordo

@MainActor
final class PreviewPanelControllerTests: XCTestCase {
    func testPresentationUsesExplicitLayerOpacityAnimationAfterPanelIsOrderedFront() throws {
        let panel = TrackingPreviewPanel()
        let controller = makeController(layoutPanel: panel)
        defer { controller.invalidate() }

        controller.show(
            layout: .right,
            targetFrame: screen.visibleFrame,
            screen: screen
        )

        let hostView = try XCTUnwrap(panel.contentViewController?.view)
        let layer = try XCTUnwrap(hostView.layer)
        let animation = try XCTUnwrap(
            layer.animation(forKey: PreviewPanelController.presentationAnimationKey)
                as? CABasicAnimation
        )

        XCTAssertEqual(panel.orderFrontCallCount, 1)
        XCTAssertEqual(panel.orderFrontContentCounts, [1])
        XCTAssertEqual(panel.alphaValue, 1)
        XCTAssertEqual(panel.animationBehavior, .none)
        XCTAssertTrue(hostView.wantsLayer)
        XCTAssertEqual(layer.opacity, 1)
        XCTAssertEqual(animation.keyPath, "opacity")
        XCTAssertEqual((animation.fromValue as? NSNumber)?.doubleValue, 0)
        XCTAssertEqual((animation.toValue as? NSNumber)?.doubleValue, 1)
        XCTAssertEqual(animation.duration, 0.14, accuracy: 0.000_1)
        assertTimingFunction(animation.timingFunction, equals: CAMediaTimingFunction(name: .easeOut))
    }

    func testReduceMotionPresentsImmediatelyWithoutAnimation() throws {
        let panel = TrackingPreviewPanel()
        let controller = makeController(layoutPanel: panel, reduceMotion: true)
        defer { controller.invalidate() }

        controller.show(
            layout: .right,
            targetFrame: screen.visibleFrame,
            screen: screen
        )

        let layer = try XCTUnwrap(panel.contentViewController?.view.layer)
        XCTAssertNil(layer.animation(forKey: PreviewPanelController.presentationAnimationKey))
        XCTAssertEqual(layer.opacity, 1)
        XCTAssertEqual(panel.alphaValue, 1)
    }

    func testShowingSameVisibleLayoutKeepsHostAndDoesNotRestartAnimation() throws {
        let panel = TrackingPreviewPanel()
        let controller = makeController(layoutPanel: panel)
        defer { controller.invalidate() }

        controller.show(
            layout: .right,
            targetFrame: screen.visibleFrame,
            screen: screen
        )
        let firstHost = try XCTUnwrap(panel.contentViewController?.view)
        firstHost.layer?.removeAnimation(forKey: PreviewPanelController.presentationAnimationKey)

        controller.show(
            layout: .right,
            targetFrame: screen.visibleFrame,
            screen: screen
        )

        XCTAssertTrue(firstHost === panel.contentViewController?.view)
        XCTAssertNil(firstHost.layer?.animation(forKey: PreviewPanelController.presentationAnimationKey))
        XCTAssertEqual(panel.orderFrontCallCount, 1)
    }

    func testDirectionChangeCreatesNewHostAndRemovesOldAnimation() throws {
        let panel = TrackingPreviewPanel()
        let controller = makeController(layoutPanel: panel)
        defer { controller.invalidate() }

        controller.show(
            layout: .right,
            targetFrame: screen.visibleFrame,
            screen: screen
        )
        let firstHost = try XCTUnwrap(panel.contentViewController?.view)
        let firstLayer = try XCTUnwrap(firstHost.layer)
        XCTAssertNotNil(firstLayer.animation(forKey: PreviewPanelController.presentationAnimationKey))

        controller.show(
            layout: .left,
            targetFrame: screen.visibleFrame,
            screen: screen
        )
        let secondHost = try XCTUnwrap(panel.contentViewController?.view)

        XCTAssertFalse(firstHost === secondHost)
        XCTAssertNil(firstLayer.animation(forKey: PreviewPanelController.presentationAnimationKey))
        XCTAssertNotNil(
            secondHost.layer?.animation(forKey: PreviewPanelController.presentationAnimationKey)
        )
        XCTAssertEqual(panel.orderFrontCallCount, 1)
    }

    func testHideLayoutClearsHostAndReusesPanelForFreshPresentation() throws {
        let panel = TrackingPreviewPanel()
        let controller = makeController(layoutPanel: panel)
        defer { controller.invalidate() }

        controller.show(
            layout: .right,
            targetFrame: screen.visibleFrame,
            screen: screen
        )
        let firstHost = try XCTUnwrap(panel.contentViewController?.view)

        controller.hideLayout()

        XCTAssertNil(firstHost.layer?.animation(forKey: PreviewPanelController.presentationAnimationKey))
        XCTAssertNil(panel.contentViewController)
        XCTAssertEqual(panel.orderOutCallCount, 1)

        controller.show(
            layout: .right,
            targetFrame: screen.visibleFrame,
            screen: screen
        )

        XCTAssertNotNil(panel.contentViewController)
        XCTAssertFalse(firstHost === panel.contentViewController?.view)
        XCTAssertEqual(panel.orderFrontCallCount, 2)
    }

    func testOneHundredPresentationCyclesKeepWindowAlphaAndReusePanel() throws {
        var panels: [TrackingPreviewPanel] = []
        let controller = PreviewPanelController(
            panelFactory: {
                let panel = TrackingPreviewPanel()
                panels.append(panel)
                return panel
            },
            markerPanelFactory: { TrackingPreviewPanel() },
            accessibilityReduceMotion: { false }
        )
        defer { controller.invalidate() }

        for index in 0..<100 {
            controller.show(
                layout: index.isMultiple(of: 2) ? .left : .right,
                targetFrame: screen.visibleFrame,
                screen: screen
            )
            let layer = try XCTUnwrap(panels[0].contentViewController?.view.layer)
            XCTAssertEqual(layer.opacity, 1)
            XCTAssertEqual(panels[0].alphaValue, 1)
            XCTAssertNotNil(layer.animation(forKey: PreviewPanelController.presentationAnimationKey))
            controller.hideLayout()
        }

        XCTAssertEqual(panels.count, 1)
        XCTAssertEqual(panels[0].orderFrontCallCount, 100)
        XCTAssertEqual(panels[0].orderOutCallCount, 100)
    }

    func testOriginMarkerUsesUnclampedConvertedPointAndExpectedPanelConfiguration() {
        let markerPanel = TrackingPreviewPanel()
        let controller = makeController(markerPanel: markerPanel)
        defer { controller.invalidate() }
        let verticallyStackedScreen = ScreenGeometry(
            displayID: 2,
            frame: CGRect(x: -800, y: 900, width: 800, height: 600),
            visibleFrame: CGRect(x: -800, y: 900, width: 800, height: 560),
            appKitFrame: CGRect(x: -800, y: -600, width: 800, height: 600),
            appKitVisibleFrame: CGRect(x: -800, y: -560, width: 800, height: 560),
            backingScaleFactor: 2,
            mainScreenFrame: CGRect(x: 0, y: 0, width: 1_000, height: 900)
        )

        controller.showOriginMarker(
            at: CGPoint(x: -100, y: 1_200),
            screen: verticallyStackedScreen
        )

        XCTAssertEqual(
            markerPanel.frame,
            CGRect(x: -120, y: -320, width: 40, height: 40)
        )
        XCTAssertEqual(markerPanel.orderFrontCallCount, 1)
        XCTAssertEqual(markerPanel.alphaValue, 1)
        XCTAssertEqual(markerPanel.animationBehavior, .none)
        XCTAssertTrue(markerPanel.ignoresMouseEvents)
        XCTAssertFalse(markerPanel.canBecomeKey)
        XCTAssertEqual(
            markerPanel.level.rawValue,
            NSWindow.Level.floating.rawValue + 2
        )
        XCTAssertNotNil(markerPanel.contentViewController)
    }

    func testOriginMarkerOnlyUsesFirstPointUntilItIsHidden() {
        let markerPanel = TrackingPreviewPanel()
        let controller = makeController(markerPanel: markerPanel)
        defer { controller.invalidate() }

        controller.showOriginMarker(at: CGPoint(x: 100, y: 200), screen: screen)
        let firstFrame = markerPanel.frame
        controller.showOriginMarker(at: CGPoint(x: 700, y: 600), screen: screen)

        XCTAssertEqual(markerPanel.frame, firstFrame)
        XCTAssertEqual(markerPanel.orderFrontCallCount, 1)

        controller.hide()
        controller.showOriginMarker(at: CGPoint(x: 700, y: 600), screen: screen)

        XCTAssertNotEqual(markerPanel.frame, firstFrame)
        XCTAssertEqual(markerPanel.orderFrontCallCount, 2)
    }

    func testOriginMarkerTracksAllEightLayoutsWithoutMovingOrReplacingItsHost() throws {
        let markerPanel = TrackingPreviewPanel()
        let controller = makeController(markerPanel: markerPanel)
        defer { controller.invalidate() }
        controller.showOriginMarker(at: CGPoint(x: 100, y: 200), screen: screen)
        let host = try markerHost(in: markerPanel)
        let originFrame = markerPanel.frame
        XCTAssertNil(host.rootView.selectedLayout)

        for layout in SnapLayout.allCases {
            controller.show(layout: layout, targetFrame: screen.visibleFrame, screen: screen)

            XCTAssertEqual(host.rootView.selectedLayout, layout)
            XCTAssertTrue(host === markerPanel.contentViewController)
            XCTAssertEqual(markerPanel.frame, originFrame)
        }

        XCTAssertEqual(markerPanel.orderFrontCallCount, 1)
    }

    func testRepeatedDirectionKeepsMarkerHostAndView() throws {
        let markerPanel = TrackingPreviewPanel()
        let controller = makeController(markerPanel: markerPanel)
        defer { controller.invalidate() }
        controller.showOriginMarker(at: CGPoint(x: 100, y: 200), screen: screen)
        controller.show(layout: .right, targetFrame: screen.visibleFrame, screen: screen)
        let host = try markerHost(in: markerPanel)
        let view = host.view

        for _ in 0..<20 {
            controller.show(layout: .right, targetFrame: screen.visibleFrame, screen: screen)
        }

        XCTAssertTrue(host === markerPanel.contentViewController)
        XCTAssertTrue(view === markerPanel.contentViewController?.view)
        XCTAssertEqual(host.rootView.selectedLayout, .right)
        XCTAssertEqual(markerPanel.orderFrontCallCount, 1)
    }

    func testClearingLayoutResetsHighlightWithoutHidingOrRecreatingMarker() throws {
        let markerPanel = TrackingPreviewPanel()
        let controller = makeController(markerPanel: markerPanel)
        defer { controller.invalidate() }
        controller.showOriginMarker(at: CGPoint(x: 100, y: 200), screen: screen)
        controller.show(layout: .topRight, targetFrame: screen.visibleFrame, screen: screen)
        let host = try markerHost(in: markerPanel)
        XCTAssertEqual(host.rootView.selectedLayout, .topRight)

        controller.hideLayout()

        XCTAssertNil(host.rootView.selectedLayout)
        XCTAssertTrue(host === markerPanel.contentViewController)
        XCTAssertEqual(markerPanel.orderOutCallCount, 0)

        controller.show(layout: .bottomLeft, targetFrame: screen.visibleFrame, screen: screen)
        XCTAssertEqual(host.rootView.selectedLayout, .bottomLeft)
    }

    func testClearingBeforeAnyLayoutPresentationKeepsNeutralMarker() throws {
        let markerPanel = TrackingPreviewPanel()
        var layoutPanelCount = 0
        let controller = PreviewPanelController(
            panelFactory: {
                layoutPanelCount += 1
                return TrackingPreviewPanel()
            },
            markerPanelFactory: { markerPanel }
        )
        defer { controller.invalidate() }
        controller.showOriginMarker(at: CGPoint(x: 100, y: 200), screen: screen)
        let host = try markerHost(in: markerPanel)

        controller.hideLayout()

        XCTAssertNil(host.rootView.selectedLayout)
        XCTAssertEqual(layoutPanelCount, 0)
        XCTAssertEqual(markerPanel.orderOutCallCount, 0)
        XCTAssertTrue(host === markerPanel.contentViewController)
    }

    func testFullHideClearsHighlightAndNextGestureStartsWithFreshNeutralHost() throws {
        let markerPanel = TrackingPreviewPanel()
        let controller = makeController(markerPanel: markerPanel)
        defer { controller.invalidate() }
        controller.showOriginMarker(at: CGPoint(x: 100, y: 200), screen: screen)
        controller.show(layout: .bottomRight, targetFrame: screen.visibleFrame, screen: screen)
        let host = try markerHost(in: markerPanel)
        XCTAssertEqual(host.rootView.selectedLayout, .bottomRight)

        controller.hide()

        XCTAssertNil(host.rootView.selectedLayout)
        XCTAssertNil(markerPanel.contentViewController)
        XCTAssertEqual(markerPanel.orderOutCallCount, 1)

        controller.showOriginMarker(at: CGPoint(x: 300, y: 400), screen: screen)
        let nextHost = try markerHost(in: markerPanel)
        XCTAssertNil(nextHost.rootView.selectedLayout)
        XCTAssertFalse(host === nextHost)
        XCTAssertEqual(markerPanel.frame, CGRect(x: 280, y: 380, width: 40, height: 40))
    }

    func testLayoutPresentationAloneDoesNotCreateOrReshowMarker() {
        var markerPanelCount = 0
        let controller = PreviewPanelController(
            panelFactory: { TrackingPreviewPanel() },
            markerPanelFactory: {
                markerPanelCount += 1
                return TrackingPreviewPanel()
            }
        )
        defer { controller.invalidate() }

        controller.show(layout: .right, targetFrame: screen.visibleFrame, screen: screen)
        XCTAssertEqual(markerPanelCount, 0)

        controller.showOriginMarker(at: CGPoint(x: 100, y: 200), screen: screen)
        controller.hide()
        controller.show(layout: .left, targetFrame: screen.visibleFrame, screen: screen)
        XCTAssertEqual(markerPanelCount, 1)
    }

    func testOriginMarkerCenterStaysAtScreenEdgeWithoutClamping() {
        let markerPanel = TrackingPreviewPanel()
        let controller = makeController(markerPanel: markerPanel)
        defer { controller.invalidate() }

        controller.showOriginMarker(at: .zero, screen: screen)

        XCTAssertEqual(markerPanel.frame, CGRect(x: -20, y: 780, width: 40, height: 40))
    }

    func testHideLayoutKeepsOriginMarkerUntilFullHide() {
        let layoutPanel = TrackingPreviewPanel()
        let markerPanel = TrackingPreviewPanel()
        let controller = makeController(
            layoutPanel: layoutPanel,
            markerPanel: markerPanel
        )
        defer { controller.invalidate() }

        controller.showOriginMarker(at: CGPoint(x: 100, y: 200), screen: screen)
        controller.show(
            layout: .right,
            targetFrame: screen.visibleFrame,
            screen: screen
        )

        controller.hideLayout()

        XCTAssertEqual(layoutPanel.orderOutCallCount, 1)
        XCTAssertEqual(markerPanel.orderOutCallCount, 0)

        controller.hide()

        XCTAssertEqual(layoutPanel.orderOutCallCount, 1)
        XCTAssertEqual(markerPanel.orderOutCallCount, 1)
    }

    func testInvalidationDiscardsBothPanelsBeforeNextPresentation() throws {
        var layoutPanels: [TrackingPreviewPanel] = []
        var markerPanels: [TrackingPreviewPanel] = []
        let controller = PreviewPanelController(
            panelFactory: {
                let panel = TrackingPreviewPanel()
                layoutPanels.append(panel)
                return panel
            },
            markerPanelFactory: {
                let panel = TrackingPreviewPanel()
                markerPanels.append(panel)
                return panel
            },
            accessibilityReduceMotion: { false }
        )
        defer { controller.invalidate() }

        controller.showOriginMarker(at: CGPoint(x: 100, y: 200), screen: screen)
        controller.show(
            layout: .right,
            targetFrame: screen.visibleFrame,
            screen: screen
        )
        let oldMarkerHost = try markerHost(in: markerPanels[0])
        XCTAssertEqual(oldMarkerHost.rootView.selectedLayout, .right)

        controller.invalidate()

        XCTAssertEqual(layoutPanels[0].closeCallCount, 1)
        XCTAssertEqual(markerPanels[0].closeCallCount, 1)
        XCTAssertNil(oldMarkerHost.rootView.selectedLayout)
        XCTAssertNil(markerPanels[0].contentViewController)

        controller.showOriginMarker(at: CGPoint(x: 300, y: 400), screen: screen)
        let newMarkerHost = try markerHost(in: markerPanels[1])
        XCTAssertNil(newMarkerHost.rootView.selectedLayout)
        controller.show(
            layout: .left,
            targetFrame: screen.visibleFrame,
            screen: screen
        )
        XCTAssertEqual(newMarkerHost.rootView.selectedLayout, .left)

        XCTAssertEqual(layoutPanels.count, 2)
        XCTAssertEqual(markerPanels.count, 2)
        XCTAssertFalse(layoutPanels[0] === layoutPanels[1])
        XCTAssertFalse(markerPanels[0] === markerPanels[1])
    }

    private func markerHost(in panel: NSPanel) throws -> NSHostingController<SnapOriginMarkerView> {
        try XCTUnwrap(panel.contentViewController as? NSHostingController<SnapOriginMarkerView>)
    }

    private func makeController(
        layoutPanel: TrackingPreviewPanel = TrackingPreviewPanel(),
        markerPanel: TrackingPreviewPanel = TrackingPreviewPanel(),
        reduceMotion: Bool = false
    ) -> PreviewPanelController {
        PreviewPanelController(
            panelFactory: { layoutPanel },
            markerPanelFactory: { markerPanel },
            accessibilityReduceMotion: { reduceMotion }
        )
    }

    private func assertTimingFunction(
        _ actual: CAMediaTimingFunction?,
        equals expected: CAMediaTimingFunction,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("缺少动画缓动函数", file: file, line: line)
            return
        }
        for index in 0..<4 {
            let actualPoint = controlPoint(index, of: actual)
            let expectedPoint = controlPoint(index, of: expected)
            XCTAssertEqual(actualPoint.x, expectedPoint.x, accuracy: 0.000_1, file: file, line: line)
            XCTAssertEqual(actualPoint.y, expectedPoint.y, accuracy: 0.000_1, file: file, line: line)
        }
    }

    private func controlPoint(
        _ index: Int,
        of timingFunction: CAMediaTimingFunction
    ) -> (x: Float, y: Float) {
        var values = [Float](repeating: 0, count: 2)
        values.withUnsafeMutableBufferPointer { buffer in
            timingFunction.getControlPoint(at: index, values: buffer.baseAddress!)
        }
        return (values[0], values[1])
    }

    private var screen: ScreenGeometry {
        ScreenGeometry(
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            appKitFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            appKitVisibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            backingScaleFactor: 1,
            mainScreenFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
        )
    }
}

@MainActor
private final class TrackingPreviewPanel: NSPanel {
    private(set) var orderFrontCallCount = 0
    private(set) var orderFrontContentCounts: [Int] = []
    private(set) var orderOutCallCount = 0
    private(set) var closeCallCount = 0

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
    }

    override func orderFrontRegardless() {
        orderFrontCallCount += 1
        orderFrontContentCounts.append(contentViewController == nil ? 0 : 1)
        super.orderFrontRegardless()
    }

    override func orderOut(_ sender: Any?) {
        orderOutCallCount += 1
        super.orderOut(sender)
    }

    override func close() {
        closeCallCount += 1
        super.close()
    }
}
