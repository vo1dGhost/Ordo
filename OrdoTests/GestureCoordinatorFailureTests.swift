import CoreGraphics
import Foundation
import XCTest
@testable import Ordo

@MainActor
final class GestureCoordinatorFailureTests: XCTestCase {
    func testRaiseFailureStopsSessionReportsOnceAndDoesNotWriteGeometry() async throws {
        let controller = FailureWindowController(scenario: .raiseFails)
        let status = FailureStatusRecorder()
        let outcomes = FailureOutcomeRecorder()
        let coordinator = makeCoordinator(
            controller: controller,
            status: status,
            outcomes: outcomes
        )

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForMetrics(controller, description: "等待窗口捕获") {
            $0.captureCount == 1
        }
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 130, y: 120)))

        try await waitForMetrics(controller, description: "等待单窗口置前失败后的释放") {
            $0.raiseAttempts == 1 && $0.releaseCount == 1
        }
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 180, y: 160)))
        try await allowAsynchronousWorkToSettle()

        let metrics = await controller.metrics()
        XCTAssertEqual(metrics.raiseAttempts, 1)
        XCTAssertEqual(metrics.raiseCompletions, 0)
        XCTAssertEqual(metrics.positionAttempts, 0)
        XCTAssertEqual(metrics.frameAttempts, 0)
        XCTAssertEqual(metrics.releaseCount, 1)
        XCTAssertEqual(status.messages, [FailureWindowError.raiseFailed.localizedDescription])
        XCTAssertTrue(outcomes.values.isEmpty)
    }

    func testRaiseFailureAfterReleaseReportsOnceWithoutTerminalWrite() async throws {
        let controller = FailureWindowController(scenario: .blockedRaiseFails)
        let status = FailureStatusRecorder()
        let outcomes = FailureOutcomeRecorder()
        let coordinator = makeCoordinator(
            controller: controller,
            status: status,
            outcomes: outcomes
        )

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForMetrics(controller, description: "等待窗口捕获") {
            $0.captureCount == 1
        }
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 130, y: 120)))
        try await waitForMetrics(controller, description: "等待单窗口置前进入阻塞点") {
            $0.raiseIsBlocked
        }
        coordinator.handle(flags([], at: CGPoint(x: 130, y: 120)))
        await controller.resumeBlockedRaise()

        try await waitForMetrics(controller, description: "等待松键后的置前失败释放") {
            $0.releaseCount == 1
        }
        try await allowAsynchronousWorkToSettle()

        let metrics = await controller.metrics()
        XCTAssertEqual(metrics.raiseAttempts, 1)
        XCTAssertEqual(metrics.raiseCompletions, 0)
        XCTAssertEqual(metrics.positionAttempts, 0)
        XCTAssertEqual(metrics.releaseCount, 1)
        XCTAssertEqual(status.messages, [FailureWindowError.raiseFailed.localizedDescription])
        XCTAssertTrue(outcomes.values.isEmpty)
    }

    func testSnapRaiseFailureWhileModifiersRemainPressedHidesMarkerAndEndsSession() async throws {
        let controller = FailureWindowController(scenario: .raiseFails)
        let status = FailureStatusRecorder()
        let preview = FailurePreviewDisplay()
        let outcomes = FailureOutcomeRecorder()
        let coordinator = makeCoordinator(
            controller: controller,
            status: status,
            preview: preview,
            outcomes: outcomes
        )

        coordinator.handle(flags(.defaultSnap, at: CGPoint(x: 500, y: 400)))
        try await waitForOriginMarkerCount(1, preview: preview)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))

        try await waitForMetrics(controller, description: "等待排布置前失败后的窗口释放") {
            $0.raiseAttempts == 1 && $0.releaseCount == 1
        }
        try await allowAsynchronousWorkToSettle()

        let metrics = await controller.metrics()
        XCTAssertEqual(metrics.raiseCompletions, 0)
        XCTAssertEqual(metrics.frameAttempts, 0)
        XCTAssertEqual(status.messages, [FailureWindowError.raiseFailed.localizedDescription])
        XCTAssertEqual(preview.originMarkerCount, 1)
        XCTAssertFalse(preview.isOriginMarkerVisible)
        XCTAssertEqual(preview.hideCount, 1)
        XCTAssertTrue(outcomes.values.isEmpty)
    }

    func testQueuedCancellationAfterRaiseFailureSuppressesStaleStatus() async throws {
        let controller = FailureWindowController(scenario: .raiseFails)
        let status = FailureStatusRecorder()
        let outcomes = FailureOutcomeRecorder()
        let coordinator = makeCoordinator(
            controller: controller,
            status: status,
            outcomes: outcomes
        )
        await controller.setAfterRaiseFailure {
            Task { @MainActor in
                coordinator.cancelCurrentSession()
            }
        }

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForMetrics(controller, description: "等待窗口捕获") {
            $0.captureCount == 1
        }
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 130, y: 120)))

        try await waitForMetrics(controller, description: "等待排队取消后的释放") {
            $0.releaseCount == 1
        }
        try await allowAsynchronousWorkToSettle()

        let metrics = await controller.metrics()
        XCTAssertEqual(metrics.raiseAttempts, 1)
        XCTAssertEqual(metrics.positionAttempts, 0)
        XCTAssertEqual(metrics.releaseCount, 1)
        XCTAssertTrue(status.messages.isEmpty)
        XCTAssertTrue(outcomes.values.isEmpty)
    }

    func testFirstPositionFailureStopsSessionAndDoesNotRetryOnLaterMouseMoves() async throws {
        let controller = FailureWindowController(scenario: .firstPositionFails)
        let status = FailureStatusRecorder()
        let outcomes = FailureOutcomeRecorder()
        let coordinator = makeCoordinator(
            controller: controller,
            status: status,
            outcomes: outcomes
        )

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 50, y: 50)))
        try await waitForMetrics(controller, description: "等待窗口捕获") {
            $0.captureCount == 1
        }
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 80, y: 70)))

        try await waitForMetrics(controller, description: "等待位置写入失败后的窗口释放") {
            $0.positionAttempts == 1 && $0.releaseCount == 1
        }
        XCTAssertEqual(status.messages.last, FailureWindowError.positionFailed.localizedDescription)

        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 120, y: 90)))
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 160, y: 130)))
        try await allowAsynchronousWorkToSettle()

        let metrics = await controller.metrics()
        XCTAssertEqual(metrics.positionAttempts, 1)
        XCTAssertEqual(metrics.completedPositionWrites, 0)
        XCTAssertEqual(metrics.releaseCount, 1)
        XCTAssertTrue(outcomes.values.isEmpty)
    }

    func testMouseMoveAfterNormalReleaseDoesNotWriteAgain() async throws {
        let controller = FailureWindowController(scenario: .succeeds)
        let coordinator = makeCoordinator(controller: controller)

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 200, y: 150)))
        try await waitForMetrics(controller, description: "等待窗口捕获") {
            $0.captureCount == 1
        }
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 230, y: 175)))
        coordinator.handle(flags([], at: CGPoint(x: 230, y: 175)))

        try await waitForMetrics(controller, description: "等待正常松键完成") {
            $0.releaseCount == 1
        }
        let writesAtRelease = await controller.metrics().completedPositionWrites
        XCTAssertGreaterThanOrEqual(writesAtRelease, 1)

        coordinator.handle(mouse([], at: CGPoint(x: 400, y: 400)))
        try await allowAsynchronousWorkToSettle()

        let metrics = await controller.metrics()
        XCTAssertEqual(metrics.completedPositionWrites, writesAtRelease)
        XCTAssertEqual(metrics.releaseCount, 1)
    }

    func testCancellationWhilePositionWriteIsBlockedPreventsTheActualWrite() async throws {
        let controller = FailureWindowController(scenario: .blockFirstPosition)
        let outcomes = FailureOutcomeRecorder()
        let coordinator = makeCoordinator(controller: controller, outcomes: outcomes)

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 10, y: 10)))
        try await waitForMetrics(controller, description: "等待窗口捕获") {
            $0.captureCount == 1
        }
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 40, y: 40)))

        try await waitForMetrics(controller, description: "等待位置写入进入可控阻塞点") {
            $0.positionIsBlocked
        }
        coordinator.cancelCurrentSession()
        await controller.resumeBlockedPosition()

        try await waitForMetrics(controller, description: "等待取消后的窗口释放") {
            $0.releaseCount == 1
        }
        try await allowAsynchronousWorkToSettle()

        var metrics = await controller.metrics()
        XCTAssertEqual(metrics.raiseCompletions, 1)
        XCTAssertEqual(metrics.positionAttempts, 1)
        XCTAssertEqual(metrics.completedPositionWrites, 0)

        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 90, y: 90)))
        try await allowAsynchronousWorkToSettle()
        metrics = await controller.metrics()
        XCTAssertEqual(metrics.positionAttempts, 1)
        XCTAssertEqual(metrics.completedPositionWrites, 0)
        XCTAssertTrue(outcomes.values.isEmpty)
    }

    func testSnapFrameFailureReportsOnceWithoutSuccessfulOutcome() async throws {
        let controller = FailureWindowController(scenario: .frameFails)
        let status = FailureStatusRecorder()
        let outcomes = FailureOutcomeRecorder()
        let coordinator = makeCoordinator(
            controller: controller,
            status: status,
            outcomes: outcomes
        )

        let start = CGPoint(x: 500, y: 400)
        coordinator.handle(flags(.defaultSnap, at: start))
        try await waitForMetrics(controller, description: "等待窗口捕获") {
            $0.captureCount == 1
        }
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))
        coordinator.handle(flags([], at: CGPoint(x: 530, y: 400)))

        try await waitForMetrics(controller, description: "等待排布失败后的窗口释放") {
            $0.frameAttempts == 1 && $0.releaseCount == 1
        }
        try await allowAsynchronousWorkToSettle()

        let metrics = await controller.metrics()
        XCTAssertEqual(metrics.frameAttempts, 1)
        XCTAssertEqual(metrics.releaseCount, 1)
        XCTAssertEqual(status.messages, [FailureWindowError.frameFailed.localizedDescription])
        XCTAssertTrue(outcomes.values.isEmpty)
    }

    func testSnapCaptureFailureHidesPreviewWithoutShowingOriginMarker() async throws {
        let controller = FailureWindowController(scenario: .captureFails)
        let status = FailureStatusRecorder()
        let preview = FailurePreviewDisplay()
        let coordinator = makeCoordinator(
            controller: controller,
            status: status,
            preview: preview
        )

        coordinator.handle(flags(.defaultSnap, at: CGPoint(x: 500, y: 400)))

        try await waitForMetrics(controller, description: "等待窗口捕获失败") {
            $0.captureCount == 1
        }
        try await allowAsynchronousWorkToSettle()

        XCTAssertEqual(status.messages, [FailureWindowError.captureFailed.localizedDescription])
        XCTAssertEqual(preview.originMarkerCount, 0)
        XCTAssertEqual(preview.hideCount, 1)
    }

    func testCaptureFailurePreservesFullReleaseWhileNextChordIsBeingPressed() async throws {
        let releasedAt = CGPoint(x: 130, y: 100)
        for releaseEvent in [flags([], at: releasedAt), mouse([], at: releasedAt)] {
            let controller = FailureWindowController(scenario: .firstCaptureFails)
            let status = FailureStatusRecorder()
            let outcomes = FailureOutcomeRecorder()
            let coordinator = makeCoordinator(
                controller: controller,
                status: status,
                outcomes: outcomes
            )

            // 同一批输入先完整松键，再开始逐键按下新组合；此时旧捕获尚未返回。
            coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
            coordinator.handle(mouse(.defaultMove, at: releasedAt))
            coordinator.handle(releaseEvent)
            coordinator.handle(flags([.option], at: CGPoint(x: 200, y: 200)))
            try await waitForMetrics(controller, description: "等待旧捕获失败处理完成") {
                $0.captureCount == 1 && status.messages.count == 1
            }

            coordinator.handle(flags(.defaultResize, at: CGPoint(x: 200, y: 200)))
            coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 240, y: 230)))
            coordinator.handle(flags([], at: CGPoint(x: 240, y: 230)))
            try await waitForMetrics(controller, description: "等待下一轮缩放完成并释放") {
                $0.releaseCount == 1
            }

            let metrics = await controller.metrics()
            XCTAssertEqual(metrics.captureCount, 2)
            XCTAssertEqual(metrics.raiseAttempts, 1)
            XCTAssertEqual(metrics.positionAttempts, 0)
            XCTAssertEqual(metrics.sizeAttempts, 1)
            XCTAssertEqual(metrics.lastSize, CGSize(width: 440, height: 330))
            XCTAssertEqual(metrics.releaseCount, 1)
            XCTAssertEqual(status.messages, [FailureWindowError.captureFailed.localizedDescription])
            XCTAssertEqual(outcomes.values, [.resized])
        }
    }

    func testCaptureFailureWithoutFullReleaseWaitsBeforeStartingAnotherGesture() async throws {
        for remainingModifiers in [ModifierChord.defaultMove, [.shift]] {
            let controller = FailureWindowController(scenario: .firstCaptureFails)
            let status = FailureStatusRecorder()
            let outcomes = FailureOutcomeRecorder()
            let coordinator = makeCoordinator(
                controller: controller,
                status: status,
                outcomes: outcomes
            )

            coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
            coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 130, y: 100)))
            coordinator.handle(flags(remainingModifiers, at: CGPoint(x: 130, y: 100)))
            try await waitForMetrics(controller, description: "等待未完整松键的捕获失败") {
                $0.captureCount == 1 && status.messages.count == 1
            }

            coordinator.handle(flags(.defaultResize, at: CGPoint(x: 200, y: 200)))
            coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 240, y: 230)))
            try await allowAsynchronousWorkToSettle()
            var metrics = await controller.metrics()
            XCTAssertEqual(metrics.captureCount, 1)
            XCTAssertEqual(metrics.raiseAttempts, 0)
            XCTAssertEqual(metrics.sizeAttempts, 0)
            XCTAssertTrue(outcomes.values.isEmpty)

            coordinator.handle(flags([], at: CGPoint(x: 240, y: 230)))
            coordinator.handle(flags(.defaultResize, at: CGPoint(x: 200, y: 200)))
            coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 240, y: 230)))
            coordinator.handle(flags([], at: CGPoint(x: 240, y: 230)))
            try await waitForMetrics(controller, description: "等待完整松键后的缩放恢复") {
                $0.releaseCount == 1
            }

            metrics = await controller.metrics()
            XCTAssertEqual(metrics.captureCount, 2)
            XCTAssertEqual(metrics.raiseAttempts, 1)
            XCTAssertEqual(metrics.positionAttempts, 0)
            XCTAssertEqual(metrics.sizeAttempts, 1)
            XCTAssertEqual(metrics.lastSize, CGSize(width: 440, height: 330))
            XCTAssertEqual(status.messages, [FailureWindowError.captureFailed.localizedDescription])
            XCTAssertEqual(outcomes.values, [.resized])
        }
    }

    private func makeCoordinator(
        controller: FailureWindowController,
        status: FailureStatusRecorder = FailureStatusRecorder(),
        preview: FailurePreviewDisplay = FailurePreviewDisplay(),
        outcomes: FailureOutcomeRecorder = FailureOutcomeRecorder()
    ) -> GestureCoordinator {
        GestureCoordinator(
            windowController: controller,
            screenProvider: FailureScreenProvider(),
            previewController: preview,
            onStatus: { [weak status] message in
                status?.messages.append(message)
            },
            onOutcome: { [weak outcomes] outcome in
                outcomes?.values.append(outcome)
            }
        )
    }

    private func flags(_ modifiers: ModifierChord, at point: CGPoint) -> InputEvent {
        InputEvent(
            kind: .flagsChanged,
            modifiers: modifiers,
            location: point,
            timestamp: 0
        )
    }

    private func mouse(_ modifiers: ModifierChord, at point: CGPoint) -> InputEvent {
        InputEvent(
            kind: .mouseMoved,
            modifiers: modifiers,
            location: point,
            timestamp: 0
        )
    }

    private func waitForMetrics(
        _ controller: FailureWindowController,
        description: String,
        condition: (FailureWindowController.Metrics) -> Bool
    ) async throws {
        for _ in 0..<250 {
            if condition(await controller.metrics()) {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail(description)
    }

    private func waitForOriginMarkerCount(
        _ expected: Int,
        preview: FailurePreviewDisplay
    ) async throws {
        for _ in 0..<250 {
            if preview.originMarkerCount == expected {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待起点标记显示超时")
    }

    private func allowAsynchronousWorkToSettle() async throws {
        for _ in 0..<10 {
            await Task.yield()
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}

private enum FailureWindowError: Error, LocalizedError, Sendable {
    case captureFailed
    case raiseFailed
    case positionFailed
    case frameFailed

    var errorDescription: String? {
        switch self {
        case .captureFailed:
            "模拟窗口捕获失败"
        case .raiseFailed:
            "模拟单窗口置前失败"
        case .positionFailed:
            "模拟位置写入失败"
        case .frameFailed:
            "模拟排布写入失败"
        }
    }
}

private actor FailureWindowController: WindowControlling {
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        MainActor.sharedUnownedExecutor
    }

    enum Scenario: Sendable {
        case succeeds
        case raiseFails
        case blockedRaiseFails
        case firstPositionFails
        case blockFirstPosition
        case frameFails
        case captureFails
        case firstCaptureFails
    }

    struct Metrics: Sendable {
        var captureCount = 0
        var raiseAttempts = 0
        var raiseCompletions = 0
        var raiseIsBlocked = false
        var positionAttempts = 0
        var completedPositionWrites = 0
        var positionIsBlocked = false
        var sizeAttempts = 0
        var lastSize: CGSize?
        var frameAttempts = 0
        var releaseCount = 0
    }

    private let scenario: Scenario
    private var state = Metrics()
    private var blockedPositionContinuation: CheckedContinuation<Void, Never>?
    private var blockedRaiseContinuation: CheckedContinuation<Void, Never>?
    private var afterRaiseFailure: (@Sendable () -> Void)?

    init(scenario: Scenario) {
        self.scenario = scenario
    }

    func captureWindow(at point: CGPoint, for mode: InteractionMode) async throws -> WindowSnapshot {
        state.captureCount += 1
        if scenario == .captureFails || (scenario == .firstCaptureFails && state.captureCount == 1) {
            throw FailureWindowError.captureFailed
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

    func raiseWindow(_ window: WindowSnapshot) async throws {
        state.raiseAttempts += 1
        if scenario == .raiseFails {
            let action = afterRaiseFailure
            afterRaiseFailure = nil
            action?()
            throw FailureWindowError.raiseFailed
        }
        if scenario == .blockedRaiseFails {
            state.raiseIsBlocked = true
            await withCheckedContinuation { continuation in
                blockedRaiseContinuation = continuation
            }
            state.raiseIsBlocked = false
            try Task.checkCancellation()
            throw FailureWindowError.raiseFailed
        }
        state.raiseCompletions += 1
    }

    func setPosition(_ position: CGPoint, of window: WindowSnapshot) async throws -> WindowSnapshot {
        state.positionAttempts += 1

        if scenario == .firstPositionFails, state.positionAttempts == 1 {
            throw FailureWindowError.positionFailed
        }

        if scenario == .blockFirstPosition, state.positionAttempts == 1 {
            state.positionIsBlocked = true
            await withCheckedContinuation { continuation in
                blockedPositionContinuation = continuation
            }
            state.positionIsBlocked = false
            try Task.checkCancellation()
        }

        state.completedPositionWrites += 1
        return WindowSnapshot(
            id: window.id,
            frame: CGRect(origin: position, size: window.frame.size),
            pid: window.pid
        )
    }

    func setSize(_ size: CGSize, of window: WindowSnapshot) async throws -> WindowSnapshot {
        state.sizeAttempts += 1
        state.lastSize = size
        return WindowSnapshot(
            id: window.id,
            frame: CGRect(origin: window.frame.origin, size: size),
            pid: window.pid
        )
    }

    func applyFrame(
        _ frame: CGRect,
        to window: WindowSnapshot,
        transition: WindowFrameTransition
    ) async throws -> WindowSnapshot {
        state.frameAttempts += 1
        if scenario == .frameFails {
            throw FailureWindowError.frameFailed
        }
        return WindowSnapshot(id: window.id, frame: frame, pid: window.pid)
    }

    func release(_ window: WindowSnapshot) async {
        state.releaseCount += 1
    }

    func releaseAll() async {}

    func resumeBlockedPosition() {
        blockedPositionContinuation?.resume()
        blockedPositionContinuation = nil
    }

    func resumeBlockedRaise() {
        blockedRaiseContinuation?.resume()
        blockedRaiseContinuation = nil
    }

    func setAfterRaiseFailure(_ action: @escaping @Sendable () -> Void) {
        afterRaiseFailure = action
    }

    func metrics() -> Metrics {
        state
    }
}

@MainActor
private final class FailureStatusRecorder {
    var messages: [String] = []
}

@MainActor
private final class FailureOutcomeRecorder {
    var values: [GestureOutcome] = []
}

@MainActor
private final class FailureScreenProvider: ScreenGeometryProviding {
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
private final class FailurePreviewDisplay: PreviewDisplaying {
    private(set) var originMarkerCount = 0
    private(set) var hideCount = 0
    private(set) var isOriginMarkerVisible = false

    func show(layout: SnapLayout, targetFrame: CGRect, screen: ScreenGeometry) {}
    func showOriginMarker(at location: CGPoint, screen: ScreenGeometry) {
        originMarkerCount += 1
        isOriginMarkerVisible = true
    }
    func hideLayout() {}
    func hide() {
        hideCount += 1
        isOriginMarkerVisible = false
    }
}
