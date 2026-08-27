import CoreGraphics
import XCTest
@testable import Ordo

@MainActor
final class GestureCoordinatorTests: XCTestCase {
    func testTwoConsecutiveMoveGesturesRearmAfterAllModifiersAreReleased() async throws {
        let windowController = MockWindowController()
        let coordinator = makeCoordinator(windowController: windowController)

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 120, y: 115)))
        coordinator.handle(flags([], at: CGPoint(x: 120, y: 115)))
        try await waitForReleaseCount(1, controller: windowController)

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 200, y: 200)))
        try await waitForCaptureCount(2, controller: windowController)
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 230, y: 210)))
        coordinator.handle(flags([], at: CGPoint(x: 230, y: 210)))
        try await waitForReleaseCount(2, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.captureModes, [.move, .move])
        XCTAssertEqual(metrics.lastPosition, CGPoint(x: 80, y: 60))
        XCTAssertEqual(metrics.raiseCount, 2)
    }

    func testMoveInsideFourPointDeadZoneDoesNotRaiseOrWrite() async throws {
        let windowController = MockWindowController()
        let coordinator = makeCoordinator(windowController: windowController)

        coordinator.handle(flags(.defaultMove, at: .zero))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 4, y: 0)))
        coordinator.handle(flags([], at: CGPoint(x: 4, y: 0)))
        try await waitForReleaseCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.raiseCount, 0)
        XCTAssertEqual(metrics.positionWriteCount, 0)
        XCTAssertEqual(metrics.sizeWriteCount, 0)
    }

    func testSnapShowsPreviewAndCommitsRightHalfOnlyOnRelease() async throws {
        let windowController = MockWindowController()
        let preview = MockPreviewDisplay()
        let coordinator = makeCoordinator(
            windowController: windowController,
            preview: preview
        )

        let start = CGPoint(x: 500, y: 400)
        coordinator.handle(flags(.defaultSnap, at: start))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))
        await Task.yield()

        var metrics = await windowController.metrics()
        XCTAssertEqual(metrics.appliedFrames.count, 0)
        XCTAssertEqual(preview.lastLayout, .right)
        XCTAssertEqual(preview.lastFrame, CGRect(x: 500, y: 0, width: 500, height: 800))

        coordinator.handle(flags([], at: CGPoint(x: 530, y: 400)))
        try await waitForReleaseCount(1, controller: windowController)

        metrics = await windowController.metrics()
        XCTAssertEqual(metrics.captureModes, [.snap])
        XCTAssertEqual(metrics.appliedFrames, [CGRect(x: 500, y: 0, width: 500, height: 800)])
        XCTAssertGreaterThanOrEqual(preview.hideCount, 1)
    }

    func testSnapRaisesAfterFourPointsWithoutSelectingInsideRadialDeadZone() async throws {
        let windowController = MockWindowController()
        let preview = MockPreviewDisplay()
        let coordinator = makeCoordinator(windowController: windowController, preview: preview)
        let start = CGPoint(x: 500, y: 400)

        coordinator.handle(flags(.defaultSnap, at: start))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 504.01, y: 400)))
        coordinator.handle(flags([], at: CGPoint(x: 504.01, y: 400)))
        try await waitForReleaseCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.raiseCount, 1)
        XCTAssertEqual(metrics.appliedFrames.count, 0)
        XCTAssertNil(preview.lastLayout)
    }

    func testQuickMoveIsBufferedWhileWindowCaptureIsPending() async throws {
        let windowController = MockWindowController(captureDelayNanoseconds: 30_000_000)
        let coordinator = makeCoordinator(windowController: windowController)

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 135, y: 120)))
        coordinator.handle(flags([], at: CGPoint(x: 135, y: 120)))

        try await waitForReleaseCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.captureModes, [.move])
        XCTAssertEqual(metrics.lastPosition, CGPoint(x: 85, y: 70))
        XCTAssertEqual(metrics.raiseCount, 1)
    }

    func testPendingSnapCaptureReplaysOutwardAndReturnPathForHysteresis() async throws {
        let windowController = MockWindowController(captureDelayNanoseconds: 30_000_000)
        let coordinator = makeCoordinator(windowController: windowController)
        let start = CGPoint(x: 500, y: 400)

        coordinator.handle(flags(.defaultSnap, at: start))
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 520, y: 400)))
        coordinator.handle(flags([], at: CGPoint(x: 520, y: 400)))

        try await waitForAppliedFrameCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.captureModes, [.snap])
        XCTAssertEqual(metrics.appliedFrames, [CGRect(x: 500, y: 0, width: 500, height: 800)])
        XCTAssertEqual(metrics.raiseCount, 1)
    }

    func testLongerExactChordReplacesContainedChordBeforeActivation() async throws {
        let windowController = MockWindowController(captureDelayNanoseconds: 10_000_000)
        let preview = MockPreviewDisplay()
        let coordinator = makeCoordinator(windowController: windowController, preview: preview)
        let shortChord: ModifierChord = [.command, .control]
        let longChord: ModifierChord = [.command, .control, .shift]
        coordinator.updateShortcuts(
            resize: shortChord,
            snap: longChord,
            move: [.option, .shift]
        )

        let start = CGPoint(x: 500, y: 400)
        coordinator.handle(flags(shortChord, at: start))
        coordinator.handle(flags(longChord, at: start))
        coordinator.handle(mouse(longChord, at: CGPoint(x: 530, y: 400)))
        coordinator.handle(flags([], at: CGPoint(x: 530, y: 400)))

        try await waitForAppliedFrameCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.captureModes.last, .snap)
        XCTAssertEqual(metrics.positionWriteCount, 0)
        XCTAssertEqual(metrics.sizeWriteCount, 0)
        XCTAssertEqual(metrics.appliedFrames, [CGRect(x: 500, y: 0, width: 500, height: 800)])
    }

    func testReleasingLongChordToContainedChordEndsInsteadOfReplacingSession() async throws {
        let windowController = MockWindowController()
        let coordinator = makeCoordinator(windowController: windowController)
        let shortChord: ModifierChord = [.command, .control]
        let longChord: ModifierChord = [.command, .control, .shift]
        coordinator.updateShortcuts(
            resize: shortChord,
            snap: longChord,
            move: [.option, .shift]
        )

        coordinator.handle(flags(longChord, at: CGPoint(x: 500, y: 400)))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(flags(shortChord, at: CGPoint(x: 500, y: 400)))
        coordinator.handle(mouse(shortChord, at: CGPoint(x: 560, y: 400)))
        coordinator.handle(flags([], at: CGPoint(x: 560, y: 400)))
        try await waitForReleaseCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.captureModes, [.snap])
        XCTAssertEqual(metrics.positionWriteCount, 0)
        XCTAssertEqual(metrics.sizeWriteCount, 0)
        XCTAssertEqual(metrics.appliedFrames.count, 0)
    }

    func testMouseFlagsEndSessionWhenReleaseFlagsEventWasDropped() async throws {
        let windowController = MockWindowController()
        let coordinator = makeCoordinator(windowController: windowController)

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 120, y: 110)))

        // 模拟 AsyncStream 拥塞时 flagsChanged 松键事件被淘汰。
        coordinator.handle(mouse([], at: CGPoint(x: 240, y: 220)))
        try await waitForReleaseCount(1, controller: windowController)
        coordinator.handle(mouse([], at: CGPoint(x: 300, y: 300)))
        await Task.yield()

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.lastPosition, CGPoint(x: 70, y: 60))
        XCTAssertEqual(metrics.releaseCount, 1)
    }

    private func makeCoordinator(
        windowController: MockWindowController,
        preview: MockPreviewDisplay = MockPreviewDisplay()
    ) -> GestureCoordinator {
        GestureCoordinator(
            windowController: windowController,
            screenProvider: MockScreenProvider(),
            previewController: preview,
            onStatus: { _ in }
        )
    }

    private func flags(_ modifiers: ModifierChord, at point: CGPoint) -> InputEvent {
        InputEvent(kind: .flagsChanged, modifiers: modifiers, location: point, timestamp: 0)
    }

    private func mouse(_ modifiers: ModifierChord, at point: CGPoint) -> InputEvent {
        InputEvent(kind: .mouseMoved, modifiers: modifiers, location: point, timestamp: 0)
    }

    private func waitForCaptureCount(
        _ expected: Int,
        controller: MockWindowController
    ) async throws {
        for _ in 0..<100 {
            if await controller.metrics().captureModes.count >= expected {
                await Task.yield()
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待窗口捕获超时")
    }

    private func waitForReleaseCount(
        _ expected: Int,
        controller: MockWindowController
    ) async throws {
        for _ in 0..<100 {
            if await controller.metrics().releaseCount >= expected {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待窗口释放超时")
    }

    private func waitForAppliedFrameCount(
        _ expected: Int,
        controller: MockWindowController
    ) async throws {
        for _ in 0..<200 {
            if await controller.metrics().appliedFrames.count >= expected {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待排布写入超时")
    }
}

private actor MockWindowController: WindowControlling {
    struct Metrics: Sendable {
        var captureModes: [InteractionMode] = []
        var raiseCount = 0
        var positionWriteCount = 0
        var sizeWriteCount = 0
        var lastPosition: CGPoint?
        var appliedFrames: [CGRect] = []
        var releaseCount = 0
    }

    private var state = Metrics()
    private let captureDelayNanoseconds: UInt64

    init(captureDelayNanoseconds: UInt64 = 0) {
        self.captureDelayNanoseconds = captureDelayNanoseconds
    }

    func captureWindow(at point: CGPoint, for mode: InteractionMode) async throws -> WindowSnapshot {
        state.captureModes.append(mode)
        if captureDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: captureDelayNanoseconds)
        }
        return WindowSnapshot(
            id: UUID(),
            frame: CGRect(x: 50, y: 50, width: 400, height: 300),
            pid: 42
        )
    }

    func currentFrame(of window: WindowSnapshot) async throws -> CGRect {
        window.frame
    }

    func setPosition(_ position: CGPoint, of window: WindowSnapshot) async throws -> WindowSnapshot {
        state.positionWriteCount += 1
        state.lastPosition = position
        return WindowSnapshot(
            id: window.id,
            frame: CGRect(origin: position, size: window.frame.size),
            pid: window.pid
        )
    }

    func setSize(_ size: CGSize, of window: WindowSnapshot) async throws -> WindowSnapshot {
        state.sizeWriteCount += 1
        return WindowSnapshot(
            id: window.id,
            frame: CGRect(origin: window.frame.origin, size: size),
            pid: window.pid
        )
    }

    func applyFrame(_ frame: CGRect, to window: WindowSnapshot) async throws -> WindowSnapshot {
        state.appliedFrames.append(frame)
        return WindowSnapshot(id: window.id, frame: frame, pid: window.pid)
    }

    func activateAndRaise(_ window: WindowSnapshot) async throws {
        state.raiseCount += 1
    }

    func release(_ window: WindowSnapshot) async {
        state.releaseCount += 1
    }

    func releaseAll() async {}

    func metrics() -> Metrics {
        state
    }
}

@MainActor
private final class MockScreenProvider: ScreenGeometryProviding {
    private let screen = ScreenGeometry(
        displayID: 1,
        frame: CGRect(x: 0, y: 0, width: 1000, height: 900),
        visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
        appKitFrame: CGRect(x: 0, y: 0, width: 1000, height: 900),
        appKitVisibleFrame: CGRect(x: 0, y: 100, width: 1000, height: 800),
        backingScaleFactor: 2,
        mainScreenFrame: CGRect(x: 0, y: 0, width: 1000, height: 900)
    )

    func currentScreens() -> [ScreenGeometry] { [screen] }
    func screen(containingAXPoint point: CGPoint) -> ScreenGeometry? { screen }
    func screenAtPointer() -> ScreenGeometry? { screen }
    func screenChanges() -> AsyncStream<[ScreenGeometry]> {
        AsyncStream { continuation in
            continuation.yield([screen])
            continuation.finish()
        }
    }
}

@MainActor
private final class MockPreviewDisplay: PreviewDisplaying {
    private(set) var lastLayout: SnapLayout?
    private(set) var lastFrame: CGRect?
    private(set) var hideCount = 0

    func show(layout: SnapLayout, targetFrame: CGRect, screen: ScreenGeometry) {
        lastLayout = layout
        lastFrame = targetFrame
    }

    func hide() {
        hideCount += 1
    }
}
