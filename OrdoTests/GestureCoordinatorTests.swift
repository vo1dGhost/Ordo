import AppKit
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
@testable import Ordo

@MainActor
final class GestureCoordinatorTests: XCTestCase {
    func testSlowResizeConsumesLatestInputWithoutReplayingIntermediateSizes() async throws {
        let relay = InputEventRelay(scheduleMouseFlush: { _, action in action() })
        relay.startAccepting(epoch: 1)
        let windows = MockWindowController()
        let coordinator = makeCoordinator(windowController: windows)
        let consumer = Task {
            for await batch in relay.stream {
                for event in batch.takeEvents() { coordinator.handle(event) }
            }
        }
        defer { relay.finish(); consumer.cancel(); coordinator.cancelCurrentSession() }

        Self.recordResizeEvent(.flagsChanged, x: 100, into: relay)
        try await waitForCaptureCount(1, controller: windows)
        await windows.setDuringNextSizeWrite {
            // 模拟同步 AX 占用主执行器期间，输入线程已经记录后续鼠标位置。
            for x in stride(from: 140, through: 500, by: 20) {
                Self.recordResizeEvent(.mouseMoved, x: x, into: relay)
            }
        }
        Self.recordResizeEvent(.mouseMoved, x: 120, into: relay)
        for _ in 0..<200 {
            if await windows.metrics().lastSize?.width == 800 { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        let tracking = await windows.metrics()
        XCTAssertEqual(tracking.writtenSizes.map(\.width), [420, 800], "慢调用结束后应直接采用最新位置，不能逐个补写旧尺寸")

        Self.recordResizeEvent(.flagsChanged, x: 500, released: true, into: relay)
        try await waitForReleaseCount(1, controller: windows)
        let finished = await windows.metrics()
        XCTAssertEqual(finished.lastSize?.width, 800)
        XCTAssertEqual(finished.sizeReadbackCount, 1)
    }

    nonisolated private static func recordResizeEvent(
        _ type: CGEventType,
        x: Int,
        released: Bool = false,
        into relay: InputEventRelay
    ) {
        guard let event = CGEvent(source: nil) else { return }
        event.location = CGPoint(x: x, y: 100)
        event.flags = released ? [] : [.maskAlternate, .maskShift]
        relay.record(type: type, event: event)
    }

    func testReleaseDuringSlowResizeCommitsOnlyFinalSize() async throws {
        let relay = InputEventRelay(scheduleMouseFlush: { _, action in action() })
        relay.startAccepting(epoch: 1)
        let windows = MockWindowController()
        let coordinator = makeCoordinator(windowController: windows)
        let consumer = Task {
            for await batch in relay.stream {
                for event in batch.takeEvents() { coordinator.handle(event) }
            }
        }
        defer { relay.finish(); consumer.cancel(); coordinator.cancelCurrentSession() }
        Self.recordResizeEvent(.flagsChanged, x: 100, into: relay)
        try await waitForCaptureCount(1, controller: windows)
        await windows.setDuringNextSizeWrite {
            for x in stride(from: 140, through: 500, by: 20) {
                Self.recordResizeEvent(.mouseMoved, x: x, into: relay)
            }
            Self.recordResizeEvent(.flagsChanged, x: 500, released: true, into: relay)
        }
        Self.recordResizeEvent(.mouseMoved, x: 120, into: relay)
        try await waitForReleaseCount(1, controller: windows)
        let metrics = await windows.metrics()
        XCTAssertEqual(metrics.writtenSizes.map(\.width), [420])
        XCTAssertEqual(metrics.lastSize?.width, 800)
        XCTAssertEqual(metrics.sizeWriteCount, 2)
        XCTAssertEqual(metrics.sizeReadbackCount, 1)
        XCTAssertEqual(metrics.activeContinuousCount, 0)
    }

    func testBatchKeepsResizeActivationWhenMouseReturnsToDeadZone() async throws {
        let windows = MockWindowController()
        let coordinator = makeCoordinator(windowController: windows)
        coordinator.handle(flags(.defaultResize, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windows)
        let batch = InputEventBatch([
            mouse(.defaultResize, at: CGPoint(x: 120, y: 100)),
            mouse(.defaultResize, at: CGPoint(x: 101, y: 100)),
            flags([], at: CGPoint(x: 101, y: 100))
        ])
        for event in batch.takeEvents() { coordinator.handle(event) }
        try await waitForReleaseCount(1, controller: windows)
        let metrics = await windows.metrics()
        XCTAssertEqual(metrics.raisedWindowIDs.count, 1)
        XCTAssertEqual(metrics.sizeWriteCount, 1)
        XCTAssertEqual(metrics.lastSize?.width, 401)
    }

    func testBatchPreservesRadialHysteresisPathBeforeRelease() async throws {
        let windows = MockWindowController()
        let coordinator = makeCoordinator(windowController: windows)
        coordinator.handle(flags(.defaultSnap, at: CGPoint(x: 500, y: 400)))
        try await waitForCaptureCount(1, controller: windows)
        let batch = InputEventBatch([mouse(.defaultSnap, at: CGPoint(x: 530, y: 400))])
        for _ in 0..<40 {
            XCTAssertTrue(batch.append(mouse(.defaultSnap, at: CGPoint(x: 520, y: 400))))
        }
        XCTAssertTrue(batch.append(flags([], at: CGPoint(x: 520, y: 400))))
        for event in batch.takeEvents() { coordinator.handle(event) }
        try await waitForReleaseCount(1, controller: windows)
        let metrics = await windows.metrics()
        XCTAssertEqual(metrics.appliedFrames, [CGRect(x: 500, y: 0, width: 500, height: 800)])
    }

    func testInputOverflowCancelsWithoutFinalWriteAndWaitsForFullRelease() async throws {
        let windows = MockWindowController()
        let coordinator = makeCoordinator(windowController: windows)
        let point = CGPoint(x: 100, y: 100)
        coordinator.handle(flags(.defaultResize, at: point))
        try await waitForCaptureCount(1, controller: windows)
        coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 120, y: 100)))
        try await waitForMotionWriteCount(1, mode: .resize, controller: windows)
        coordinator.handle(InputEvent(kind: .inputOverflow, modifiers: .defaultResize, location: point, timestamp: 0))
        coordinator.handle(flags(.defaultResize, at: point))
        coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 150, y: 100)))
        try await waitForReleaseCount(1, controller: windows)
        let cancelled = await windows.metrics()
        XCTAssertEqual(cancelled.captureModes.count, 1)
        XCTAssertEqual(cancelled.sizeWriteCount, 1)
        XCTAssertEqual(cancelled.sizeReadbackCount, 0)
        XCTAssertEqual(cancelled.activeContinuousCount, 0)
        coordinator.handle(flags([], at: point))
        coordinator.handle(flags(.defaultResize, at: point))
        try await waitForCaptureCount(2, controller: windows)
        coordinator.handle(flags([], at: point))
        try await waitForReleaseCount(2, controller: windows)
    }


    func testContinuousInteractionBeginsOnceAfterRaiseAndEndsWithRelease() async throws {
        for (mode, chord) in [(InteractionMode.move, ModifierChord.defaultMove), (.resize, .defaultResize)] {
            let controller = MockWindowController()
            let coordinator = makeCoordinator(windowController: controller)
            coordinator.handle(flags(chord, at: CGPoint(x: 100, y: 100)))
            try await waitForCaptureCount(1, controller: controller)
            coordinator.handle(mouse(chord, at: CGPoint(x: 120, y: 125)))
            try await waitForMotionWriteCount(1, mode: mode, controller: controller)
            coordinator.handle(mouse(chord, at: CGPoint(x: 140, y: 150)))
            try await waitForMotionWriteCount(2, mode: mode, controller: controller)
            coordinator.handle(flags([], at: CGPoint(x: 140, y: 150)))
            try await waitForReleaseCount(1, controller: controller)
            let metrics = await controller.metrics()
            XCTAssertEqual(metrics.continuousWindowIDs, metrics.capturedWindowIDs)
            XCTAssertTrue(metrics.continuousBeganAfterRaise)
            XCTAssertTrue(metrics.writesHadContinuousInteraction)
            XCTAssertEqual(metrics.releasedWindowIDs, metrics.continuousWindowIDs)
        }
    }

    func testQueuedCancellationAfterContinuousPreparationPreventsGeometryWrite() async throws {
        let windows = MockWindowController()
        let coordinator = makeCoordinator(windowController: windows)
        await windows.setAfterContinuousBeginReturns {
            Task { @MainActor in coordinator.cancelCurrentSession() }
        }
        coordinator.handle(flags(.defaultResize, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windows)
        coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 120, y: 125)))
        try await waitForReleaseCount(1, controller: windows)
        let metrics = await windows.metrics()
        XCTAssertEqual(metrics.continuousWindowIDs, metrics.capturedWindowIDs)
        XCTAssertEqual(metrics.releasedWindowIDs, metrics.continuousWindowIDs)
        XCTAssertEqual(metrics.sizeWriteCount, 0)
        XCTAssertEqual(metrics.activeContinuousCount, 0)
    }

    func testFailedContinuousPreparationReleasesWindowWithoutWritingGeometry() async throws {
        let windows = MockWindowController(failsContinuousPreparation: true)
        let coordinator = makeCoordinator(windowController: windows)
        coordinator.handle(flags(.defaultResize, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windows)
        coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 120, y: 125)))
        try await waitForReleaseCount(1, controller: windows)
        let metrics = await windows.metrics()
        XCTAssertEqual(metrics.continuousWindowIDs, metrics.capturedWindowIDs)
        XCTAssertEqual(metrics.releasedWindowIDs, metrics.continuousWindowIDs)
        XCTAssertEqual(metrics.sizeWriteCount, 0)
        XCTAssertEqual(metrics.activeContinuousCount, 0)
    }

    func testContinuousMoveDefersReadbackUntilFinalCommit() async throws {
        let windows = MockWindowController()
        let coordinator = makeCoordinator(windowController: windows)
        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windows)

        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 120, y: 110)))
        try await waitForMotionWriteCount(1, mode: .move, controller: windows)
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 150, y: 140)))
        try await waitForMotionWriteCount(2, mode: .move, controller: windows)
        let tracking = await windows.metrics()
        XCTAssertEqual(tracking.positionReadbackCount, 0)
        XCTAssertEqual(tracking.lastPosition, CGPoint(x: 100, y: 90))

        coordinator.handle(flags([], at: CGPoint(x: 150, y: 140)))
        try await waitForReleaseCount(1, controller: windows)
        let finished = await windows.metrics()
        XCTAssertEqual(finished.positionReadbackCount, 1)
        XCTAssertEqual(finished.positionWriteCount, 3)
        XCTAssertEqual(finished.lastPosition, CGPoint(x: 100, y: 90))
    }

    func testContinuousResizeDefersReadbackUntilFinalCommit() async throws {
        let windows = MockWindowController()
        let coordinator = makeCoordinator(windowController: windows)
        coordinator.handle(flags(.defaultResize, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windows)

        coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 130, y: 120)))
        try await waitForMotionWriteCount(1, mode: .resize, controller: windows)
        coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 150, y: 140)))
        try await waitForMotionWriteCount(2, mode: .resize, controller: windows)
        let tracking = await windows.metrics()
        XCTAssertEqual(tracking.sizeReadbackCount, 0)
        XCTAssertEqual(tracking.lastSize, CGSize(width: 450, height: 340))

        coordinator.handle(flags([], at: CGPoint(x: 150, y: 140)))
        try await waitForReleaseCount(1, controller: windows)
        let finished = await windows.metrics()
        XCTAssertEqual(finished.sizeReadbackCount, 1)
        XCTAssertEqual(finished.sizeWriteCount, 3)
        XCTAssertEqual(finished.lastSize, CGSize(width: 450, height: 340))
    }

    func testCancelledMotionDoesNotReadBackOrCommitQueuedInput() async throws {
        for (mode, chord) in [(InteractionMode.move, ModifierChord.defaultMove), (.resize, .defaultResize)] {
            let windows = MockWindowController()
            let coordinator = makeCoordinator(windowController: windows)
            coordinator.handle(flags(chord, at: CGPoint(x: 100, y: 100)))
            try await waitForCaptureCount(1, controller: windows)
            coordinator.handle(mouse(chord, at: CGPoint(x: 120, y: 110)))
            try await waitForMotionWriteCount(1, mode: mode, controller: windows)

            coordinator.handle(mouse(chord, at: CGPoint(x: 180, y: 160)))
            coordinator.cancelCurrentSession()
            coordinator.handle(flags([], at: CGPoint(x: 180, y: 160)))
            try await waitForReleaseCount(1, controller: windows)
            let metrics = await windows.metrics()
            XCTAssertEqual(metrics.positionReadbackCount + metrics.sizeReadbackCount, 0)
            XCTAssertEqual(metrics.positionWriteCount + metrics.sizeWriteCount, 1)
            XCTAssertEqual(metrics.activeContinuousCount, 0)
            XCTAssertEqual(metrics.continuousWindowIDs, metrics.releasedWindowIDs)
        }
    }

    func testMoveRaisesOnlyCapturedExternalWindowOnce() async throws {
        let windowController = MockWindowController()
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            outcomes: outcomes
        )

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 120, y: 115)))
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 120, y: 115)))
        coordinator.handle(flags([], at: CGPoint(x: 120, y: 115)))
        try await waitForReleaseCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.raisedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertGreaterThanOrEqual(metrics.positionWriteCount, 1)
        XCTAssertEqual(metrics.lastPosition, CGPoint(x: 70, y: 65))
        XCTAssertEqual(outcomes.values, [.moved])
    }

    func testResizeRaisesOnlyCapturedExternalWindowOnce() async throws {
        let windowController = MockWindowController()
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            outcomes: outcomes
        )

        coordinator.handle(flags(.defaultResize, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 130, y: 120)))
        coordinator.handle(flags([], at: CGPoint(x: 130, y: 120)))
        try await waitForReleaseCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.raisedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertGreaterThanOrEqual(metrics.sizeWriteCount, 1)
        XCTAssertEqual(metrics.lastSize, CGSize(width: 430, height: 320))
        XCTAssertEqual(outcomes.values, [.resized])
    }

    func testSnapRaisesOnlyCapturedExternalWindowOnce() async throws {
        let windowController = MockWindowController()
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            outcomes: outcomes
        )
        let start = CGPoint(x: 500, y: 400)

        coordinator.handle(flags(.defaultSnap, at: start))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))
        coordinator.handle(flags([], at: CGPoint(x: 530, y: 400)))
        try await waitForReleaseCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.raisedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertEqual(metrics.appliedFrames, [CGRect(x: 500, y: 0, width: 500, height: 800)])
        XCTAssertEqual(outcomes.values, [.snapped(.right)])
    }

    func testTwoConsecutiveMoveGesturesRearmAfterAllModifiersAreReleased() async throws {
        let windowController = MockWindowController()
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            outcomes: outcomes
        )

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
        XCTAssertEqual(outcomes.values, [.moved, .moved])
    }

    func testRepeatedCancellationStillRequiresAllModifiersToBeReleasedBeforeRearming() async throws {
        let windowController = MockWindowController()
        let coordinator = makeCoordinator(windowController: windowController)

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.cancelCurrentSession()
        coordinator.cancelCurrentSession()
        try await waitForReleaseCount(1, controller: windowController)

        // 连续系统中断不能解除门控；只松开 Shift 后重新按下仍未全部松键。
        coordinator.handle(flags(.control, at: CGPoint(x: 200, y: 200)))
        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 200, y: 200)))
        try await Task.sleep(nanoseconds: 10_000_000)
        let metricsBeforeFullRelease = await windowController.metrics()
        XCTAssertEqual(metricsBeforeFullRelease.captureModes.count, 1)

        coordinator.handle(flags([], at: CGPoint(x: 200, y: 200)))
        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 300, y: 300)))
        try await waitForCaptureCount(2, controller: windowController)
        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.captureModes, [.move, .move])
        coordinator.cancelCurrentSession()
    }

    func testAllGesturesInsideFourPointDeadZoneDoNotRaiseWriteOrProduceOutcome() async throws {
        for chord in [ModifierChord.defaultMove, .defaultResize, .defaultSnap] {
            let windowController = MockWindowController()
            let outcomes = GestureOutcomeRecorder()
            let coordinator = makeCoordinator(
                windowController: windowController,
                outcomes: outcomes
            )

            coordinator.handle(flags(chord, at: .zero))
            try await waitForCaptureCount(1, controller: windowController)
            coordinator.handle(mouse(chord, at: CGPoint(x: 4, y: 0)))
            coordinator.handle(flags([], at: CGPoint(x: 4, y: 0)))
            try await waitForReleaseCount(1, controller: windowController)

            let metrics = await windowController.metrics()
            XCTAssertTrue(metrics.raisedWindowIDs.isEmpty)
            XCTAssertTrue(metrics.continuousWindowIDs.isEmpty)
            XCTAssertEqual(metrics.positionWriteCount, 0)
            XCTAssertEqual(metrics.sizeWriteCount, 0)
            XCTAssertTrue(metrics.appliedFrames.isEmpty)
            XCTAssertTrue(outcomes.values.isEmpty)
        }
    }

    func testActiveMoveReturningToFourPointBoundaryCommitsFinalPositionOnRelease() async throws {
        let windowController = MockWindowController()
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            outcomes: outcomes
        )

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 150, y: 100)))
        try await waitForPositionWriteCount(1, controller: windowController)

        // 最后一笔鼠标位置与松键连续交付，收尾必须补写已激活手势的最终位置。
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 104, y: 100)))
        coordinator.handle(flags([], at: CGPoint(x: 104, y: 100)))
        try await waitForReleaseCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.lastPosition, CGPoint(x: 54, y: 50))
        XCTAssertEqual(metrics.raisedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertEqual(outcomes.values, [.moved])
    }

    func testActiveResizeReturningToOriginCommitsOriginalSizeOnRelease() async throws {
        let windowController = MockWindowController()
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            outcomes: outcomes
        )

        let start = CGPoint(x: 100, y: 100)
        coordinator.handle(flags(.defaultResize, at: start))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 150, y: 120)))
        try await waitForSizeWriteCount(1, controller: windowController)

        coordinator.handle(mouse(.defaultResize, at: start))
        coordinator.handle(flags([], at: start))
        try await waitForReleaseCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.lastSize, CGSize(width: 400, height: 300))
        XCTAssertEqual(metrics.raisedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertEqual(outcomes.values, [.resized])
    }

    func testSnapShowsPreviewAndCommitsRightHalfOnlyOnRelease() async throws {
        let windowController = MockWindowController()
        let preview = MockPreviewDisplay()
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            preview: preview,
            outcomes: outcomes
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
        XCTAssertEqual(metrics.appliedTransitions, [.animated(.snapDefault)])
        XCTAssertGreaterThanOrEqual(preview.hideCount, 1)
        XCTAssertEqual(outcomes.values, [.snapped(.right)])
    }

    func testSnapShowsOriginMarkerBeforeReplayingBufferedMouseLocations() async throws {
        let windowController = MockWindowController(captureDelayNanoseconds: 30_000_000)
        let preview = MockPreviewDisplay()
        let coordinator = makeCoordinator(windowController: windowController, preview: preview)
        let start = CGPoint(x: 500, y: 400)

        coordinator.handle(flags(.defaultSnap, at: start))
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))

        XCTAssertTrue(preview.originMarkerLocations.isEmpty)
        XCTAssertTrue(preview.events.isEmpty)

        try await waitForPreviewEventCount(2, preview: preview)

        XCTAssertEqual(preview.originMarkerLocations, [start])
        XCTAssertEqual(preview.originMarkerDisplayIDs, [1])
        XCTAssertEqual(preview.events, [.originMarker, .layout(.right)])
        XCTAssertTrue(preview.isOriginMarkerVisible)

        coordinator.cancelCurrentSession()
        XCTAssertFalse(preview.isOriginMarkerVisible)
    }

    func testSnapReleasedDuringCaptureDoesNotShowOriginMarker() async throws {
        let windowController = MockWindowController(captureDelayNanoseconds: 30_000_000)
        let preview = MockPreviewDisplay()
        let coordinator = makeCoordinator(windowController: windowController, preview: preview)
        let start = CGPoint(x: 500, y: 400)

        coordinator.handle(flags(.defaultSnap, at: start))
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))
        coordinator.handle(flags([], at: CGPoint(x: 530, y: 400)))

        try await waitForReleaseCount(1, controller: windowController)

        XCTAssertTrue(preview.originMarkerLocations.isEmpty)
        XCTAssertTrue(preview.events.isEmpty)
        XCTAssertFalse(preview.isOriginMarkerVisible)
        XCTAssertGreaterThanOrEqual(preview.hideCount, 1)
    }

    func testReturningToSnapClearRadiusHidesOnlyLayoutAndKeepsOriginMarker() async throws {
        let windowController = MockWindowController()
        let preview = MockPreviewDisplay()
        let coordinator = makeCoordinator(windowController: windowController, preview: preview)
        let start = CGPoint(x: 500, y: 400)

        coordinator.handle(flags(.defaultSnap, at: start))
        try await waitForOriginMarkerCount(1, preview: preview)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 505, y: 400)))

        XCTAssertNil(preview.lastLayout)
        XCTAssertEqual(preview.originMarkerLocations, [start])
        XCTAssertEqual(preview.hideLayoutCount, 1)
        XCTAssertEqual(preview.hideCount, 0)
        XCTAssertTrue(preview.isOriginMarkerVisible)

        coordinator.handle(flags([], at: CGPoint(x: 505, y: 400)))
        try await waitForReleaseCount(1, controller: windowController)
        XCTAssertFalse(preview.isOriginMarkerVisible)
        XCTAssertEqual(preview.hideCount, 1)
    }

    func testMoveGestureNeverShowsOriginMarker() async throws {
        let windowController = MockWindowController()
        let preview = MockPreviewDisplay()
        let coordinator = makeCoordinator(windowController: windowController, preview: preview)

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 130, y: 120)))
        coordinator.handle(flags([], at: CGPoint(x: 130, y: 120)))
        try await waitForReleaseCount(1, controller: windowController)

        XCTAssertTrue(preview.originMarkerLocations.isEmpty)
    }

    func testRealMarkerHighlightFollowsRadialThresholdsHysteresisAndRelease() async throws {
        let windowController = MockWindowController()
        let markerPanel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let preview = PreviewPanelController(markerPanelFactory: { markerPanel })
        let coordinator = GestureCoordinator(
            windowController: windowController,
            screenProvider: MockScreenProvider(),
            previewController: preview,
            onStatus: { _ in }
        )
        defer {
            coordinator.cancelCurrentSession()
            preview.invalidate()
        }
        let start = CGPoint(x: 500, y: 400)
        coordinator.handle(flags(.defaultSnap, at: start))
        for _ in 0..<200 {
            if markerPanel.contentViewController != nil { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let host = try XCTUnwrap(
            markerPanel.contentViewController as? NSHostingController<SnapOriginMarkerView>
        )
        let originFrame = markerPanel.frame

        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 508, y: 400)))
        XCTAssertNil(host.rootView.selectedLayout)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 509, y: 400)))
        XCTAssertEqual(host.rootView.selectedLayout, .right)

        // 越过 22.5° 分界但尚在 6° 迟滞范围内，保留右方向。
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 520, y: 410)))
        XCTAssertEqual(host.rootView.selectedLayout, .right)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 526, y: 415)))
        XCTAssertEqual(host.rootView.selectedLayout, .bottomRight)

        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 505, y: 400)))
        XCTAssertNil(host.rootView.selectedLayout)
        XCTAssertTrue(host === markerPanel.contentViewController)
        XCTAssertEqual(markerPanel.frame, originFrame)

        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 500, y: 370)))
        XCTAssertEqual(host.rootView.selectedLayout, .top)
        coordinator.handle(flags([], at: CGPoint(x: 500, y: 370)))
        XCTAssertNil(host.rootView.selectedLayout)
        XCTAssertNil(markerPanel.contentViewController)
        try await waitForReleaseCount(1, controller: windowController)
    }

    func testReduceMotionUsesImmediateSnapTransition() async throws {
        let windowController = MockWindowController()
        let coordinator = makeCoordinator(
            windowController: windowController,
            snapTransition: { .immediate }
        )

        let start = CGPoint(x: 500, y: 400)
        coordinator.handle(flags(.defaultSnap, at: start))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))
        coordinator.handle(flags([], at: CGPoint(x: 530, y: 400)))
        try await waitForReleaseCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.appliedTransitions, [.immediate])
    }

    func testSnapTransitionProviderUsesLatestValueWhenGestureFinishes() async throws {
        let windowController = MockWindowController()
        let transitionState = SnapTransitionState(animationEnabled: true)
        let coordinator = makeCoordinator(
            windowController: windowController,
            snapTransition: {
                transitionState.animationEnabled ? .animated(.snapDefault) : .immediate
            }
        )

        let start = CGPoint(x: 500, y: 400)
        coordinator.handle(flags(.defaultSnap, at: start))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))

        transitionState.animationEnabled = false
        coordinator.handle(flags([], at: CGPoint(x: 530, y: 400)))
        try await waitForReleaseCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.appliedTransitions, [.immediate])
    }

    func testSnapOutcomeWaitsUntilAnimatedTransitionCompletes() async throws {
        let windowController = MockWindowController(blocksFrameApplication: true)
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            outcomes: outcomes
        )

        let start = CGPoint(x: 500, y: 400)
        coordinator.handle(flags(.defaultSnap, at: start))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))
        coordinator.handle(flags([], at: CGPoint(x: 530, y: 400)))
        try await waitForBlockedFrameApplication(controller: windowController)

        XCTAssertTrue(outcomes.values.isEmpty)
        var metrics = await windowController.metrics()
        XCTAssertEqual(metrics.releaseCount, 0)

        await windowController.resumeBlockedFrameApplication()
        try await waitForReleaseCount(1, controller: windowController)

        XCTAssertEqual(outcomes.values, [.snapped(.right)])
        metrics = await windowController.metrics()
        XCTAssertEqual(metrics.completedFrameApplications, 1)
    }

    func testNewGestureCancelsPendingSnapTransitionAtCurrentFrame() async throws {
        let windowController = MockWindowController(blocksFrameApplication: true)
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            outcomes: outcomes
        )

        let start = CGPoint(x: 500, y: 400)
        coordinator.handle(flags(.defaultSnap, at: start))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))
        coordinator.handle(flags([], at: CGPoint(x: 530, y: 400)))
        try await waitForBlockedFrameApplication(controller: windowController)

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 200, y: 200)))
        try await waitForCaptureCount(2, controller: windowController)
        try await waitForReleaseCount(1, controller: windowController)

        var metrics = await windowController.metrics()
        XCTAssertEqual(metrics.completedFrameApplications, 0)
        XCTAssertTrue(outcomes.values.isEmpty)

        coordinator.cancelCurrentSession()
        try await waitForReleaseCount(2, controller: windowController)
        metrics = await windowController.metrics()
        XCTAssertEqual(metrics.releaseCount, 2)
    }

    func testCancellationStopsPendingSnapTransitionWithoutOutcome() async throws {
        let windowController = MockWindowController(blocksFrameApplication: true)
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            outcomes: outcomes
        )

        let start = CGPoint(x: 500, y: 400)
        coordinator.handle(flags(.defaultSnap, at: start))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))
        coordinator.handle(flags([], at: CGPoint(x: 530, y: 400)))
        try await waitForBlockedFrameApplication(controller: windowController)

        coordinator.cancelCurrentSession()
        try await waitForReleaseCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.completedFrameApplications, 0)
        XCTAssertEqual(metrics.releaseCount, 1)
        XCTAssertTrue(outcomes.values.isEmpty)
    }

    func testMoveWaitsForSingleWindowRaiseBeforeWritingGeometry() async throws {
        let windowController = MockWindowController(blocksRaise: true)
        let coordinator = makeCoordinator(windowController: windowController)

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 130, y: 120)))
        try await waitForBlockedRaise(controller: windowController)

        var metrics = await windowController.metrics()
        XCTAssertEqual(metrics.raisedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertTrue(metrics.completedRaisedWindowIDs.isEmpty)
        XCTAssertEqual(metrics.positionWriteCount, 0)

        await windowController.resumeBlockedRaise()
        try await waitForPositionWriteCount(1, controller: windowController)
        coordinator.handle(flags([], at: CGPoint(x: 130, y: 120)))
        try await waitForReleaseCount(1, controller: windowController)

        metrics = await windowController.metrics()
        XCTAssertEqual(metrics.completedRaisedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertEqual(metrics.releasedWindowIDs, metrics.capturedWindowIDs)
    }

    func testQueuedCancellationAfterRaiseReturnsWinsBeforeGeometryWrite() async throws {
        let windowController = MockWindowController()
        let coordinator = makeCoordinator(windowController: windowController)
        await windowController.setAfterRaiseReturns {
            Task { @MainActor in
                coordinator.cancelCurrentSession()
            }
        }

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 130, y: 120)))
        try await waitForReleaseCount(1, controller: windowController)

        let metrics = await windowController.metrics()
        XCTAssertEqual(metrics.completedRaisedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertEqual(metrics.positionWriteCount, 0)
        XCTAssertEqual(metrics.releasedWindowIDs, metrics.capturedWindowIDs)
    }

    func testSnapReleaseWaitsForSingleWindowRaiseBeforeApplyingFrame() async throws {
        let windowController = MockWindowController(blocksRaise: true)
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            outcomes: outcomes
        )
        let start = CGPoint(x: 500, y: 400)

        coordinator.handle(flags(.defaultSnap, at: start))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 530, y: 400)))
        coordinator.handle(flags([], at: CGPoint(x: 530, y: 400)))
        try await waitForBlockedRaise(controller: windowController)

        var metrics = await windowController.metrics()
        XCTAssertTrue(metrics.appliedFrames.isEmpty)
        XCTAssertTrue(outcomes.values.isEmpty)
        XCTAssertEqual(metrics.releaseCount, 0)

        await windowController.resumeBlockedRaise()
        try await waitForReleaseCount(1, controller: windowController)

        metrics = await windowController.metrics()
        XCTAssertEqual(metrics.completedRaisedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertEqual(metrics.appliedFrames, [CGRect(x: 500, y: 0, width: 500, height: 800)])
        XCTAssertEqual(outcomes.values, [.snapped(.right)])
    }

    func testResizeReleaseWaitsForSingleWindowRaiseBeforeWritingFinalSize() async throws {
        let windowController = MockWindowController(blocksRaise: true)
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            outcomes: outcomes
        )

        coordinator.handle(flags(.defaultResize, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 130, y: 120)))
        try await waitForBlockedRaise(controller: windowController)
        coordinator.handle(flags([], at: CGPoint(x: 130, y: 120)))

        var metrics = await windowController.metrics()
        XCTAssertEqual(metrics.raisedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertTrue(metrics.completedRaisedWindowIDs.isEmpty)
        XCTAssertEqual(metrics.sizeWriteCount, 0)
        XCTAssertEqual(metrics.releaseCount, 0)
        XCTAssertTrue(outcomes.values.isEmpty)

        await windowController.resumeBlockedRaise()
        try await waitForReleaseCount(1, controller: windowController)

        metrics = await windowController.metrics()
        XCTAssertEqual(metrics.completedRaisedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertEqual(metrics.sizeWriteCount, 1)
        XCTAssertEqual(metrics.lastSize, CGSize(width: 430, height: 320))
        XCTAssertEqual(metrics.releasedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertEqual(outcomes.values, [.resized])
    }

    func testAllGesturesCancelBlockedRaiseWithoutLaterWritesAndReleaseOnce() async throws {
        for chord in [ModifierChord.defaultMove, .defaultResize, .defaultSnap] {
            let windowController = MockWindowController(blocksRaise: true)
            let outcomes = GestureOutcomeRecorder()
            let coordinator = makeCoordinator(
                windowController: windowController,
                outcomes: outcomes
            )

            coordinator.handle(flags(chord, at: CGPoint(x: 100, y: 100)))
            try await waitForCaptureCount(1, controller: windowController)
            coordinator.handle(mouse(chord, at: CGPoint(x: 130, y: 120)))
            try await waitForBlockedRaise(controller: windowController)

            coordinator.cancelCurrentSession()
            try await waitForReleaseCount(1, controller: windowController)
            try await waitForRaiseToStopBlocking(controller: windowController)

            let metrics = await windowController.metrics()
            XCTAssertEqual(metrics.raisedWindowIDs, metrics.capturedWindowIDs)
            XCTAssertTrue(metrics.completedRaisedWindowIDs.isEmpty)
            XCTAssertEqual(metrics.positionWriteCount, 0)
            XCTAssertEqual(metrics.sizeWriteCount, 0)
            XCTAssertTrue(metrics.appliedFrames.isEmpty)
            XCTAssertEqual(metrics.releasedWindowIDs, metrics.capturedWindowIDs)
            XCTAssertTrue(outcomes.values.isEmpty)
        }
    }

    func testNewGestureCancelsPendingMoveRaiseAndReleasesEachWindowOnce() async throws {
        let windowController = MockWindowController(blocksRaise: true)
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            outcomes: outcomes
        )

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 130, y: 120)))
        try await waitForBlockedRaise(controller: windowController)
        coordinator.handle(flags([], at: CGPoint(x: 130, y: 120)))

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 200, y: 200)))
        try await waitForCaptureCount(2, controller: windowController)
        try await waitForReleaseCount(1, controller: windowController)
        try await waitForRaiseToStopBlocking(controller: windowController)

        var metrics = await windowController.metrics()
        XCTAssertEqual(metrics.raisedWindowIDs, [metrics.capturedWindowIDs[0]])
        XCTAssertTrue(metrics.completedRaisedWindowIDs.isEmpty)
        XCTAssertEqual(metrics.positionWriteCount, 0)
        XCTAssertTrue(outcomes.values.isEmpty)
        XCTAssertEqual(metrics.releasedWindowIDs, [metrics.capturedWindowIDs[0]])

        coordinator.cancelCurrentSession()
        try await waitForReleaseCount(2, controller: windowController)

        metrics = await windowController.metrics()
        XCTAssertEqual(metrics.releasedWindowIDs.count, 2)
        XCTAssertEqual(Set(metrics.releasedWindowIDs), Set(metrics.capturedWindowIDs))
    }

    func testSuccessfulResizeReportsOneOutcomeAfterFinalWrite() async throws {
        let windowController = MockWindowController()
        let outcomes = GestureOutcomeRecorder()
        let coordinator = makeCoordinator(
            windowController: windowController,
            outcomes: outcomes
        )

        coordinator.handle(flags(.defaultResize, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windowController)
        coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 130, y: 120)))
        coordinator.handle(flags([], at: CGPoint(x: 130, y: 120)))
        try await waitForReleaseCount(1, controller: windowController)

        XCTAssertEqual(outcomes.values, [.resized])
    }

    func testSnapPastFourPointsRaisesOnceWithoutRadialSelectionOrCommit() async throws {
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
        XCTAssertEqual(metrics.raisedWindowIDs, metrics.capturedWindowIDs)
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
        XCTAssertEqual(metrics.raisedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertEqual(metrics.lastPosition, CGPoint(x: 85, y: 70))
    }

    func testNewGestureInSameBatchSupersedesReleasedPendingCapture() async throws {
        for nextChord in [ModifierChord.defaultMove, .defaultResize] {
            let windows = MockWindowController(captureDelayNanoseconds: 30_000_000)
            let coordinator = makeCoordinator(windowController: windows)
            defer { coordinator.cancelCurrentSession() }
            let events = InputEventBatch([
                flags(.defaultMove, at: CGPoint(x: 100, y: 100)),
                mouse(.defaultMove, at: CGPoint(x: 130, y: 100)),
                flags([], at: CGPoint(x: 130, y: 100)),
                flags(nextChord, at: CGPoint(x: 200, y: 200)),
                mouse(nextChord, at: CGPoint(x: 240, y: 230)),
                flags([], at: CGPoint(x: 240, y: 230))
            ])
            for event in events.takeEvents() { coordinator.handle(event) }
            try await waitForReleaseCount(1, controller: windows)

            let metrics = await windows.metrics()
            if nextChord == .defaultMove {
                XCTAssertEqual(metrics.lastPosition, CGPoint(x: 90, y: 80))
            } else {
                XCTAssertEqual(metrics.lastSize, CGSize(width: 440, height: 330))
                XCTAssertEqual(metrics.positionWriteCount, 0)
            }
            XCTAssertEqual(metrics.releasedWindowIDs, metrics.capturedWindowIDs)
        }
    }

    func testPendingCaptureRequiresFullReleaseBeforeStartingAnotherGesture() async throws {
        let windows = MockWindowController(captureDelayNanoseconds: 30_000_000)
        let coordinator = makeCoordinator(windowController: windows)
        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 130, y: 100)))
        coordinator.handle(flags([.shift], at: CGPoint(x: 130, y: 100)))
        coordinator.handle(flags(.defaultResize, at: CGPoint(x: 200, y: 200)))
        coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 240, y: 230)))
        coordinator.handle(flags([], at: CGPoint(x: 240, y: 230)))
        try await waitForReleaseCount(1, controller: windows)
        let metrics = await windows.metrics()
        XCTAssertEqual(metrics.captureModes, [.move])
        XCTAssertEqual(metrics.lastPosition, CGPoint(x: 80, y: 50))
        XCTAssertEqual(metrics.sizeWriteCount, 0)
    }

    func testCompletedCapturePreservesFullReleaseWhileNextChordIsBeingPressed() async throws {
        let windows = MockWindowController(captureDelayNanoseconds: 30_000_000)
        let coordinator = makeCoordinator(windowController: windows)
        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 130, y: 100)))
        coordinator.handle(flags([], at: CGPoint(x: 130, y: 100)))
        // 新组合键尚未按齐时旧捕获返回，不能把已观察到的完整松键边界丢掉。
        coordinator.handle(flags([.option], at: CGPoint(x: 200, y: 200)))
        try await waitForReleaseCount(1, controller: windows)
        coordinator.handle(flags(.defaultResize, at: CGPoint(x: 200, y: 200)))
        coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 240, y: 230)))
        coordinator.handle(flags([], at: CGPoint(x: 240, y: 230)))
        try await waitForReleaseCount(2, controller: windows)
        let metrics = await windows.metrics()
        XCTAssertEqual(metrics.captureModes, [.move, .resize])
        XCTAssertEqual(metrics.lastSize, CGSize(width: 440, height: 330))
        XCTAssertEqual(metrics.releasedWindowIDs, metrics.capturedWindowIDs)
    }

    func testSupersededCaptureThatReturnsAfterCancellationOnlyReleasesItsWindow() async throws {
        let windows = MockWindowController(
            captureDelayNanoseconds: 30_000_000,
            captureReturnsAfterCancellation: true
        )
        let coordinator = makeCoordinator(windowController: windows)
        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        try await waitForCaptureCount(1, controller: windows)
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 130, y: 100)))
        // 鼠标携带的 flags 也能提供完整松键边界。
        coordinator.handle(mouse([], at: CGPoint(x: 130, y: 100)))
        coordinator.handle(flags(.defaultResize, at: CGPoint(x: 200, y: 200)))
        coordinator.handle(mouse(.defaultResize, at: CGPoint(x: 240, y: 230)))
        coordinator.handle(flags([], at: CGPoint(x: 240, y: 230)))
        try await waitForReleaseCount(2, controller: windows)
        let metrics = await windows.metrics()
        XCTAssertEqual(metrics.captureModes, [.move, .resize])
        XCTAssertEqual(metrics.raisedWindowIDs, Array(metrics.capturedWindowIDs.suffix(1)))
        XCTAssertEqual(metrics.positionWriteCount, 0)
        XCTAssertEqual(metrics.lastSize, CGSize(width: 440, height: 330))
        XCTAssertEqual(metrics.releasedWindowIDs, metrics.capturedWindowIDs)
    }

    func testPendingCaptureLocksChordAfterCrossingActivationThreshold() async throws {
        let shortChord: ModifierChord = [.command, .control]
        let longChord: ModifierChord = [.command, .control, .shift]
        for extraKeysInMouseEvent in [false, true] {
            for returnsToOrigin in [false, true] {
                let windows = MockWindowController(captureDelayNanoseconds: 30_000_000)
                let coordinator = makeCoordinator(windowController: windows)
                coordinator.updateShortcuts(resize: shortChord, snap: longChord, move: .defaultResize)
                let origin = CGPoint(x: 500, y: 400)
                let crossed = CGPoint(x: 504.01, y: 400)
                coordinator.handle(flags(shortChord, at: origin))
                coordinator.handle(mouse(shortChord, at: crossed))
                let point = returnsToOrigin ? origin : crossed
                if returnsToOrigin { coordinator.handle(mouse(shortChord, at: origin)) }
                coordinator.handle(extraKeysInMouseEvent ? mouse(longChord, at: point) : flags(longChord, at: point))
                coordinator.handle(mouse(longChord, at: CGPoint(x: 540, y: 430)))
                coordinator.handle(flags([], at: CGPoint(x: 540, y: 430)))
                try await waitForReleaseCount(1, controller: windows)
                let metrics = await windows.metrics()
                XCTAssertEqual(metrics.captureModes, [.resize])
                XCTAssertEqual(metrics.lastSize, CGSize(width: 440, height: 330))
                XCTAssertTrue(metrics.appliedFrames.isEmpty)
                XCTAssertEqual(metrics.releasedWindowIDs, metrics.capturedWindowIDs)
            }
        }
    }

    func testPendingCaptureAtActivationThresholdStillAllowsLongerChord() async throws {
        let windows = MockWindowController(captureDelayNanoseconds: 30_000_000)
        let coordinator = makeCoordinator(windowController: windows)
        let shortChord: ModifierChord = [.command, .control]
        let longChord: ModifierChord = [.command, .control, .shift]
        coordinator.updateShortcuts(resize: shortChord, snap: longChord, move: .defaultResize)
        coordinator.handle(flags(shortChord, at: CGPoint(x: 500, y: 400)))
        coordinator.handle(mouse(shortChord, at: CGPoint(x: 504, y: 400)))
        coordinator.handle(flags(longChord, at: CGPoint(x: 504, y: 400)))
        coordinator.handle(mouse(longChord, at: CGPoint(x: 540, y: 400)))
        coordinator.handle(flags([], at: CGPoint(x: 540, y: 400)))
        try await waitForReleaseCount(1, controller: windows)
        let metrics = await windows.metrics()
        XCTAssertEqual(metrics.captureModes.last, .snap)
        XCTAssertEqual(metrics.sizeWriteCount, 0)
        XCTAssertEqual(metrics.appliedFrames, [CGRect(x: 500, y: 0, width: 500, height: 800)])
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
        XCTAssertEqual(metrics.raisedWindowIDs, metrics.capturedWindowIDs)
        XCTAssertEqual(metrics.appliedFrames, [CGRect(x: 500, y: 0, width: 500, height: 800)])
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

    func testFixedSnapDistancePreservesPathWhileCaptureIsPending() async throws {
        let windows = MockWindowController(captureDelayNanoseconds: 25_000_000)
        let preview = MockPreviewDisplay()
        let coordinator = makeCoordinator(
            windowController: windows,
            preview: preview
        )
        coordinator.handle(flags(.defaultSnap, at: CGPoint(x: 500, y: 400)))
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 508, y: 400)))
        try await waitForOriginMarkerCount(1, preview: preview)
        XCTAssertNil(preview.lastLayout)
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 509, y: 400)))
        XCTAssertEqual(preview.lastLayout, .right)
        coordinator.handle(flags([], at: CGPoint(x: 509, y: 400)))
        try await waitForReleaseCount(1, controller: windows)

        coordinator.handle(flags(.defaultSnap, at: CGPoint(x: 500, y: 400)))
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 509, y: 400)))
        coordinator.handle(mouse(.defaultSnap, at: CGPoint(x: 506, y: 400)))
        try await waitForOriginMarkerCount(2, preview: preview)
        // 6 pt 未越过进入阈值，但须保留捕获期间先越过 8 pt 的选择。
        XCTAssertEqual(preview.lastLayout, .right)
        coordinator.handle(flags([], at: CGPoint(x: 506, y: 400)))
        try await waitForReleaseCount(2, controller: windows)
    }

    private func makeCoordinator(
        windowController: MockWindowController,
        preview: MockPreviewDisplay = MockPreviewDisplay(),
        snapTransition: @escaping @MainActor () -> WindowFrameTransition = {
            .animated(.snapDefault)
        },
        outcomes: GestureOutcomeRecorder = GestureOutcomeRecorder()
    ) -> GestureCoordinator {
        GestureCoordinator(
            windowController: windowController,
            screenProvider: MockScreenProvider(),
            previewController: preview,
            onStatus: { _ in },
            snapTransition: snapTransition,
            onOutcome: { [weak outcomes] outcome in
                outcomes?.values.append(outcome)
            }
        )
    }

    func testInputRestartCancelsActiveMoveAndRequiresFullModifierRelease() async throws {
        let windows = MockWindowController()
        try await withRestartingApp(windows: windows) { _, source, _ in
            source.send(self.flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
            try await self.waitForCaptureCount(1, controller: windows)
            source.send(self.mouse(.defaultMove, at: CGPoint(x: 130, y: 100)))
            try await self.waitForMotionWriteCount(1, mode: .move, controller: windows)
            let before = await windows.metrics()
            let oldEpoch = source.epoch
            source.simulateRestart()
            try await self.waitForReleaseCount(1, controller: windows)
            source.send(self.flags([], at: CGPoint(x: 130, y: 100)), epoch: oldEpoch)
            source.send(self.mouse(.defaultMove, at: CGPoint(x: 170, y: 100)))
            source.send(self.flags(.defaultMove, at: CGPoint(x: 170, y: 100)))
            source.send(self.flags([], at: CGPoint(x: 170, y: 100)))
            try await Task.sleep(for: .milliseconds(20))
            let interrupted = await windows.metrics()
            XCTAssertEqual(interrupted.captureModes, [.move])
            XCTAssertEqual(interrupted.positionWriteCount, before.positionWriteCount)
            XCTAssertEqual(interrupted.positionReadbackCount, 0)

            source.send(self.flags(.defaultMove, at: CGPoint(x: 200, y: 200)))
            source.send(self.mouse(.defaultMove, at: CGPoint(x: 240, y: 230)))
            source.send(self.flags([], at: CGPoint(x: 240, y: 230)))
            try await self.waitForReleaseCount(2, controller: windows)
            let finished = await windows.metrics()
            XCTAssertEqual(finished.lastPosition, CGPoint(x: 90, y: 80))
            XCTAssertEqual(finished.positionReadbackCount, 1)
            XCTAssertEqual(finished.releasedWindowIDs, finished.capturedWindowIDs)
        }
    }

    func testInputRestartCancelsPendingCaptureWithoutAnotherInputEvent() async throws {
        let windows = MockWindowController(captureDelayNanoseconds: 30_000_000)
        try await withRestartingApp(windows: windows) { _, source, preview in
            source.send(self.flags(.defaultSnap, at: CGPoint(x: 500, y: 400)))
            try await self.waitForCaptureCount(1, controller: windows)
            source.simulateRestart()
            try await Task.sleep(for: .milliseconds(50))
            let metrics = await windows.metrics()
            XCTAssertEqual(metrics.releasedWindowIDs, metrics.capturedWindowIDs)
            XCTAssertTrue(metrics.raisedWindowIDs.isEmpty)
            XCTAssertFalse(preview.isOriginMarkerVisible)
        }
    }

    func testInputRestartCancelsReleasedGestureWaitingForRaiseWithoutAnotherEvent() async throws {
        let windows = MockWindowController(blocksRaise: true)
        try await withRestartingApp(windows: windows) { _, source, preview in
            source.send(self.flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
            try await self.waitForCaptureCount(1, controller: windows)
            source.send(self.mouse(.defaultMove, at: CGPoint(x: 140, y: 130)))
            for _ in 0..<100 {
                if await windows.metrics().raiseIsBlocked { break }
                try await Task.sleep(for: .milliseconds(1))
            }
            let blocked = await windows.metrics()
            XCTAssertTrue(blocked.raiseIsBlocked)
            let hideCount = preview.hideCount
            source.send(self.flags([], at: CGPoint(x: 140, y: 130)))
            for _ in 0..<100 where preview.hideCount == hideCount {
                try await Task.sleep(for: .milliseconds(1))
            }
            XCTAssertGreaterThan(preview.hideCount, hideCount)
            source.simulateRestart()
            // 已松键的最终提交也必须被取消，不能等下一条输入才发现 epoch 改变。
            await windows.resumeBlockedRaise()
            try await self.waitForReleaseCount(1, controller: windows)
            let metrics = await windows.metrics()
            XCTAssertEqual(metrics.positionWriteCount, 0)
            XCTAssertEqual(metrics.releasedWindowIDs, metrics.capturedWindowIDs)
        }
    }

    func testInputRestartWaitsForReleaseEvenWhenPreviousModifiersWereEmpty() async throws {
        let windows = MockWindowController()
        try await withRestartingApp(windows: windows) { _, source, _ in
            source.simulateRestart()
            source.send(self.flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
            source.send(self.mouse(.defaultMove, at: CGPoint(x: 140, y: 130)))
            source.send(self.flags([], at: CGPoint(x: 140, y: 130)))
            try await Task.sleep(for: .milliseconds(20))
            let interrupted = await windows.metrics()
            XCTAssertTrue(interrupted.captureModes.isEmpty)
            source.send(self.flags(.defaultMove, at: CGPoint(x: 200, y: 200)))
            source.send(self.mouse(.defaultMove, at: CGPoint(x: 240, y: 230)))
            source.send(self.flags([], at: CGPoint(x: 240, y: 230)))
            try await self.waitForReleaseCount(1, controller: windows)
            let finished = await windows.metrics()
            XCTAssertEqual(finished.captureModes, [.move])
            XCTAssertEqual(finished.lastPosition, CGPoint(x: 90, y: 80))
        }
    }

    func testInputInterruptionReleaseGateSurvivesRepeatedCancellationBeforeAnyInput() async throws {
        let windows = MockWindowController()
        let coordinator = makeCoordinator(windowController: windows)
        coordinator.handleInputInterruption()
        // 监听恢复失败、暂停或屏幕变化都可能继续取消；不能把旧的空 flags 当作新的松键。
        coordinator.cancelCurrentSession()
        coordinator.cancelCurrentSession()
        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 100, y: 100)))
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 140, y: 130)))
        coordinator.handle(flags([], at: CGPoint(x: 140, y: 130)))
        try await Task.sleep(for: .milliseconds(20))
        let interrupted = await windows.metrics()
        XCTAssertTrue(interrupted.captureModes.isEmpty)

        coordinator.handle(flags(.defaultMove, at: CGPoint(x: 200, y: 200)))
        coordinator.handle(mouse(.defaultMove, at: CGPoint(x: 240, y: 230)))
        coordinator.handle(flags([], at: CGPoint(x: 240, y: 230)))
        try await waitForReleaseCount(1, controller: windows)
        let finished = await windows.metrics()
        XCTAssertEqual(finished.captureModes, [.move])
        XCTAssertEqual(finished.lastPosition, CGPoint(x: 90, y: 80))
    }

    private func withRestartingApp(
        windows: MockWindowController,
        body: @MainActor (AppController, RestartingEventSource, MockPreviewDisplay) async throws -> Void
    ) async throws {
        let suite = "OrdoTests.InputRestart.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let source = RestartingEventSource()
        let preview = MockPreviewDisplay()
        let controller = AppController(
            defaults: defaults,
            windowController: windows,
            screenProvider: MockScreenProvider(),
            eventSource: source,
            previewController: preview,
            accessibilityTrust: { _ in true }
        )
        defer {
            controller.shutdown()
            defaults.removePersistentDomain(forName: suite)
        }
        controller.start()
        try await body(controller, source, preview)
        await controller.shutdown().value
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

    private func waitForMotionWriteCount(
        _ expected: Int,
        mode: InteractionMode,
        controller: MockWindowController
    ) async throws {
        for _ in 0..<100 {
            let metrics = await controller.metrics()
            let count = mode == .move ? metrics.positionWriteCount : metrics.sizeWriteCount
            if count >= expected { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待连续窗口写入超时")
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

    private func waitForOriginMarkerCount(
        _ expected: Int,
        preview: MockPreviewDisplay
    ) async throws {
        for _ in 0..<200 {
            if preview.originMarkerLocations.count >= expected {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待起点标记超时")
    }

    private func waitForPreviewEventCount(
        _ expected: Int,
        preview: MockPreviewDisplay
    ) async throws {
        for _ in 0..<200 {
            if preview.events.count >= expected {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待预览事件超时")
    }

    private func waitForBlockedFrameApplication(
        controller: MockWindowController
    ) async throws {
        for _ in 0..<200 {
            if await controller.metrics().frameApplicationIsBlocked {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待排布动画进入阻塞点超时")
    }

    private func waitForBlockedRaise(
        controller: MockWindowController
    ) async throws {
        for _ in 0..<200 {
            if await controller.metrics().raiseIsBlocked {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待目标窗口置前进入阻塞点超时")
    }

    private func waitForRaiseToStopBlocking(
        controller: MockWindowController
    ) async throws {
        for _ in 0..<200 {
            if !(await controller.metrics().raiseIsBlocked) {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待目标窗口置前结束阻塞超时")
    }

    private func waitForPositionWriteCount(
        _ expected: Int,
        controller: MockWindowController
    ) async throws {
        for _ in 0..<200 {
            if await controller.metrics().positionWriteCount >= expected {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待窗口位置写入超时")
    }

    private func waitForSizeWriteCount(
        _ expected: Int,
        controller: MockWindowController
    ) async throws {
        for _ in 0..<200 {
            if await controller.metrics().sizeWriteCount >= expected {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待窗口尺寸写入超时")
    }

}

@MainActor
private final class RestartingEventSource: EventSource {
    let events: AsyncStream<InputEventBatch>
    let failures = AsyncStream<EventSourceError> { _ in }
    private let continuation: AsyncStream<InputEventBatch>.Continuation
    private(set) var isRunning = false
    private(set) var epoch: UInt64 = 0
    let lastError: EventSourceError? = nil
    var onInterruption: (@MainActor () -> Void)?

    init() {
        (events, continuation) = AsyncStream<InputEventBatch>.makeStream()
    }

    func start() throws { epoch &+= 1; isRunning = true }
    func stop() { epoch &+= 1; isRunning = false }

    func simulateRestart() {
        isRunning = false
        epoch &+= 1
        onInterruption?()
        isRunning = true
    }

    func send(_ event: InputEvent, epoch: UInt64? = nil) {
        continuation.yield(InputEventBatch([InputEvent(
            kind: event.kind,
            modifiers: event.modifiers,
            location: event.location,
            timestamp: event.timestamp,
            sourceEpoch: epoch ?? self.epoch
        )]))
    }
}

private actor MockWindowController: WindowControlling {
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        MainActor.sharedUnownedExecutor
    }

    struct Metrics: Sendable {
        var captureModes: [InteractionMode] = []
        var capturedWindowIDs: [UUID] = []
        var raisedWindowIDs: [UUID] = []
        var completedRaisedWindowIDs: [UUID] = []
        var continuousWindowIDs: [UUID] = []
        var continuousBeganAfterRaise = true
        var writesHadContinuousInteraction = true
        var activeContinuousCount = 0
        var positionWriteCount = 0
        var sizeWriteCount = 0
        var positionReadbackCount = 0
        var sizeReadbackCount = 0
        var lastPosition: CGPoint?
        var lastSize: CGSize?
        var writtenSizes: [CGSize] = []
        var appliedFrames: [CGRect] = []
        var appliedTransitions: [WindowFrameTransition] = []
        var completedFrameApplications = 0
        var frameApplicationIsBlocked = false
        var raiseIsBlocked = false
        var releasedWindowIDs: [UUID] = []
        var releaseCount = 0
    }

    private var state = Metrics()
    private let captureDelayNanoseconds: UInt64
    private let captureReturnsAfterCancellation: Bool
    private let blocksFrameApplication: Bool
    private let blocksRaise: Bool
    private let capturePID: pid_t
    private var afterRaiseReturns: (@Sendable () -> Void)?
    private var afterContinuousBeginReturns: (@Sendable () -> Void)?
    private var duringNextSizeWrite: (@Sendable () -> Void)?
    private let failsContinuousPreparation: Bool
    private var activeContinuousIDs: Set<UUID> = []
    private var blockedFrameContinuation: CheckedContinuation<Void, Never>?
    private var blockedRaiseContinuation: CheckedContinuation<Void, Never>?

    init(
        captureDelayNanoseconds: UInt64 = 0,
        captureReturnsAfterCancellation: Bool = false,
        blocksFrameApplication: Bool = false,
        blocksRaise: Bool = false,
        capturePID: pid_t = 42,
        failsContinuousPreparation: Bool = false
    ) {
        self.captureDelayNanoseconds = captureDelayNanoseconds
        self.captureReturnsAfterCancellation = captureReturnsAfterCancellation
        self.blocksFrameApplication = blocksFrameApplication
        self.blocksRaise = blocksRaise
        self.capturePID = capturePID
        self.failsContinuousPreparation = failsContinuousPreparation
    }

    func captureWindow(at point: CGPoint, for mode: InteractionMode) async throws -> WindowSnapshot {
        state.captureModes.append(mode)
        if captureDelayNanoseconds > 0 {
            do {
                try await Task.sleep(nanoseconds: captureDelayNanoseconds)
            } catch {
                // 模拟同步 AX 查询已经发生，取消时仍返回需要释放的窗口引用。
                if !captureReturnsAfterCancellation { throw error }
            }
        }
        let window = WindowSnapshot(
            id: UUID(),
            frame: CGRect(x: 50, y: 50, width: 400, height: 300),
            pid: capturePID
        )
        state.capturedWindowIDs.append(window.id)
        return window
    }

    func currentFrame(of window: WindowSnapshot) async throws -> CGRect {
        window.frame
    }

    func raiseWindow(_ window: WindowSnapshot) async throws {
        state.raisedWindowIDs.append(window.id)
        if blocksRaise {
            state.raiseIsBlocked = true
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    blockedRaiseContinuation = continuation
                }
            } onCancel: {
                Task { await self.resumeBlockedRaise() }
            }
            state.raiseIsBlocked = false
            try Task.checkCancellation()
        }
        state.completedRaisedWindowIDs.append(window.id)
        let action = afterRaiseReturns
        afterRaiseReturns = nil
        action?()
    }

    func setPosition(_ position: CGPoint, of window: WindowSnapshot) async throws -> WindowSnapshot {
        state.writesHadContinuousInteraction = state.writesHadContinuousInteraction
            && state.continuousWindowIDs.contains(window.id)
        state.positionWriteCount += 1
        state.positionReadbackCount += 1
        state.lastPosition = position
        return WindowSnapshot(
            id: window.id,
            frame: CGRect(origin: position, size: window.frame.size),
            pid: window.pid
        )
    }

    func setSize(_ size: CGSize, of window: WindowSnapshot) async throws -> WindowSnapshot {
        state.writesHadContinuousInteraction = state.writesHadContinuousInteraction
            && state.continuousWindowIDs.contains(window.id)
        state.sizeWriteCount += 1
        state.sizeReadbackCount += 1
        state.lastSize = size
        return WindowSnapshot(
            id: window.id,
            frame: CGRect(origin: window.frame.origin, size: size),
            pid: window.pid
        )
    }

    func updatePosition(_ position: CGPoint, of window: WindowSnapshot) async throws {
        state.writesHadContinuousInteraction = state.writesHadContinuousInteraction
            && state.continuousWindowIDs.contains(window.id)
        state.positionWriteCount += 1
        state.lastPosition = position
    }

    func updateSize(_ size: CGSize, of window: WindowSnapshot) async throws {
        state.writesHadContinuousInteraction = state.writesHadContinuousInteraction
            && state.continuousWindowIDs.contains(window.id)
        state.sizeWriteCount += 1
        state.lastSize = size
        state.writtenSizes.append(size)
        let action = duringNextSizeWrite
        duringNextSizeWrite = nil
        action?()
    }

    func applyFrame(
        _ frame: CGRect,
        to window: WindowSnapshot,
        transition: WindowFrameTransition
    ) async throws -> WindowSnapshot {
        state.appliedFrames.append(frame)
        state.appliedTransitions.append(transition)

        if blocksFrameApplication {
            state.frameApplicationIsBlocked = true
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    blockedFrameContinuation = continuation
                }
            } onCancel: {
                Task { await self.resumeBlockedFrameApplication() }
            }
            state.frameApplicationIsBlocked = false
            try Task.checkCancellation()
        }

        state.completedFrameApplications += 1
        return WindowSnapshot(id: window.id, frame: frame, pid: window.pid)
    }

    func beginContinuousInteraction(with window: WindowSnapshot) async throws {
        state.continuousBeganAfterRaise = state.continuousBeganAfterRaise
            && state.completedRaisedWindowIDs.contains(window.id)
        state.continuousWindowIDs.append(window.id)
        activeContinuousIDs.insert(window.id)
        state.activeContinuousCount = activeContinuousIDs.count
        let action = afterContinuousBeginReturns
        afterContinuousBeginReturns = nil
        action?()
        if failsContinuousPreparation { throw AXWindowControllerError.operationTimedOut("手势准备") }
    }

    func release(_ window: WindowSnapshot) async {
        activeContinuousIDs.remove(window.id)
        state.activeContinuousCount = activeContinuousIDs.count
        state.releasedWindowIDs.append(window.id)
        state.releaseCount += 1
    }

    func releaseAll() async {}

    func resumeBlockedFrameApplication() {
        blockedFrameContinuation?.resume()
        blockedFrameContinuation = nil
    }

    func resumeBlockedRaise() {
        blockedRaiseContinuation?.resume()
        blockedRaiseContinuation = nil
    }

    func setAfterRaiseReturns(_ action: @escaping @Sendable () -> Void) {
        afterRaiseReturns = action
    }

    func setAfterContinuousBeginReturns(_ action: @escaping @Sendable () -> Void) {
        afterContinuousBeginReturns = action
    }

    func setDuringNextSizeWrite(_ action: @escaping @Sendable () -> Void) {
        duringNextSizeWrite = action
    }

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
    enum Event: Equatable {
        case originMarker
        case layout(SnapLayout)
    }

    private(set) var lastLayout: SnapLayout?
    private(set) var lastFrame: CGRect?
    private(set) var hideCount = 0
    private(set) var hideLayoutCount = 0
    private(set) var originMarkerLocations: [CGPoint] = []
    private(set) var originMarkerDisplayIDs: [CGDirectDisplayID] = []
    private(set) var isOriginMarkerVisible = false
    private(set) var events: [Event] = []

    func show(layout: SnapLayout, targetFrame: CGRect, screen: ScreenGeometry) {
        lastLayout = layout
        lastFrame = targetFrame
        events.append(.layout(layout))
    }

    func showOriginMarker(at location: CGPoint, screen: ScreenGeometry) {
        originMarkerLocations.append(location)
        originMarkerDisplayIDs.append(screen.displayID)
        isOriginMarkerVisible = true
        events.append(.originMarker)
    }

    func hideLayout() {
        hideLayoutCount += 1
        lastLayout = nil
    }

    func hide() {
        hideCount += 1
        lastLayout = nil
        isOriginMarkerVisible = false
    }
}

@MainActor
private final class GestureOutcomeRecorder {
    var values: [GestureOutcome] = []
}

@MainActor
private final class SnapTransitionState {
    var animationEnabled: Bool

    init(animationEnabled: Bool) {
        self.animationEnabled = animationEnabled
    }
}
