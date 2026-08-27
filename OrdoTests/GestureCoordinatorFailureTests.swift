import CoreGraphics
import Foundation
import XCTest
@testable import Ordo

@MainActor
final class GestureCoordinatorFailureTests: XCTestCase {
    func testRaiseFailureStopsSessionReportsStatusAndReleasesWindow() async throws {
        let controller = FailureWindowController(scenario: .raiseFails)
        let status = FailureStatusRecorder()
        let coordinator = makeCoordinator(controller: controller, status: status)

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForMetrics(controller, description: "等待窗口捕获") {
            $0.captureCount == 1
        }
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 120, y: 110)))

        try await waitForMetrics(controller, description: "等待置前失败后的窗口释放") {
            $0.raiseAttempts == 1 && $0.releaseCount == 1
        }
        XCTAssertEqual(status.messages.last, FailureWindowError.raiseFailed.localizedDescription)

        let writesAfterFailure = await controller.metrics().completedPositionWrites
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 180, y: 160)))
        try await allowAsynchronousWorkToSettle()

        let metrics = await controller.metrics()
        XCTAssertEqual(metrics.completedPositionWrites, writesAfterFailure)
        XCTAssertEqual(metrics.completedPositionWrites, 0)
        XCTAssertEqual(metrics.releaseCount, 1)
    }

    func testFirstPositionFailureStopsSessionAndDoesNotRetryOnLaterMouseMoves() async throws {
        let controller = FailureWindowController(scenario: .firstPositionFails)
        let status = FailureStatusRecorder()
        let coordinator = makeCoordinator(controller: controller, status: status)

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
        let coordinator = makeCoordinator(controller: controller)

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
        XCTAssertEqual(metrics.positionAttempts, 1)
        XCTAssertEqual(metrics.completedPositionWrites, 0)
        XCTAssertEqual(metrics.raiseCompletions, 1)

        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 90, y: 90)))
        try await allowAsynchronousWorkToSettle()
        metrics = await controller.metrics()
        XCTAssertEqual(metrics.positionAttempts, 1)
        XCTAssertEqual(metrics.completedPositionWrites, 0)
    }

    private func makeCoordinator(
        controller: FailureWindowController,
        status: FailureStatusRecorder = FailureStatusRecorder()
    ) -> GestureCoordinator {
        GestureCoordinator(
            windowController: controller,
            screenProvider: FailureScreenProvider(),
            previewController: FailurePreviewDisplay(),
            onStatus: { [weak status] message in
                status?.messages.append(message)
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

    private func allowAsynchronousWorkToSettle() async throws {
        for _ in 0..<10 {
            await Task.yield()
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}

private enum FailureWindowError: Error, LocalizedError, Sendable {
    case raiseFailed
    case positionFailed

    var errorDescription: String? {
        switch self {
        case .raiseFailed:
            "模拟置前失败"
        case .positionFailed:
            "模拟位置写入失败"
        }
    }
}

private actor FailureWindowController: WindowControlling {
    enum Scenario: Sendable {
        case succeeds
        case raiseFails
        case firstPositionFails
        case blockFirstPosition
    }

    struct Metrics: Sendable {
        var captureCount = 0
        var raiseAttempts = 0
        var raiseCompletions = 0
        var positionAttempts = 0
        var completedPositionWrites = 0
        var positionIsBlocked = false
        var releaseCount = 0
    }

    private let scenario: Scenario
    private var state = Metrics()
    private var blockedPositionContinuation: CheckedContinuation<Void, Never>?

    init(scenario: Scenario) {
        self.scenario = scenario
    }

    func captureWindow(at point: CGPoint, for mode: InteractionMode) async throws -> WindowSnapshot {
        state.captureCount += 1
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
        WindowSnapshot(
            id: window.id,
            frame: CGRect(origin: window.frame.origin, size: size),
            pid: window.pid
        )
    }

    func applyFrame(_ frame: CGRect, to window: WindowSnapshot) async throws -> WindowSnapshot {
        WindowSnapshot(id: window.id, frame: frame, pid: window.pid)
    }

    func activateAndRaise(_ window: WindowSnapshot) async throws {
        state.raiseAttempts += 1
        if scenario == .raiseFails {
            throw FailureWindowError.raiseFailed
        }
        state.raiseCompletions += 1
    }

    func release(_ window: WindowSnapshot) async {
        state.releaseCount += 1
    }

    func releaseAll() async {}

    func resumeBlockedPosition() {
        blockedPositionContinuation?.resume()
        blockedPositionContinuation = nil
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
    func show(layout: SnapLayout, targetFrame: CGRect, screen: ScreenGeometry) {}
    func hide() {}
}
