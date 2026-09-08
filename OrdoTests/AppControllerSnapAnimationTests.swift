import Foundation
import XCTest
@testable import Ordo

@MainActor
final class AppControllerSnapAnimationTests: XCTestCase {
    private let preferenceKey = "ordo.snap.animationEnabled"

    func testSnapAnimationDefaultsToEnabledAndPersistsChanges() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = AppController(
            defaults: defaults,
            accessibilityReduceMotion: { false }
        )

        XCTAssertTrue(controller.isSnapAnimationEnabled)

        controller.setSnapAnimationEnabled(false)
        XCTAssertEqual(defaults.object(forKey: preferenceKey) as? Bool, false)

        let reloadedController = AppController(
            defaults: defaults,
            accessibilityReduceMotion: { false }
        )
        XCTAssertFalse(reloadedController.isSnapAnimationEnabled)

        reloadedController.setSnapAnimationEnabled(true)
        XCTAssertEqual(defaults.object(forKey: preferenceKey) as? Bool, true)
    }

    func testDisabledSnapAnimationUsesImmediateTransition() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: preferenceKey)

        let controller = AppController(
            defaults: defaults,
            accessibilityReduceMotion: { false }
        )

        XCTAssertEqual(controller.currentSnapTransition, .immediate)
    }

    func testReduceMotionOverridesEnabledSnapAnimation() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = AppController(
            defaults: defaults,
            accessibilityReduceMotion: { true }
        )

        XCTAssertTrue(controller.isSnapAnimationEnabled)
        XCTAssertEqual(controller.currentSnapTransition, .immediate)
    }

    func testEnabledSnapAnimationUsesDefaultAnimation() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = AppController(
            defaults: defaults,
            accessibilityReduceMotion: { false }
        )

        XCTAssertEqual(controller.currentSnapTransition, .animated(.snapDefault))
    }

    func testDisablingDuringGestureUsesImmediateTransitionAtRelease() async throws {
        let (defaults, suiteName) = makeDefaults()
        let eventSource = SnapAnimationEventSource()
        let windowController = SnapAnimationWindowController()
        let controller = AppController(
            defaults: defaults,
            windowController: windowController,
            screenProvider: SnapAnimationScreenProvider(),
            eventSource: eventSource,
            previewController: SnapAnimationPreviewDisplay(),
            accessibilityTrust: { _ in true },
            accessibilityReduceMotion: { false }
        )
        defer {
            controller.shutdown()
            defaults.removePersistentDomain(forName: suiteName)
        }

        controller.start()
        try await waitForMonitoring(controller)

        eventSource.send(
            kind: .flagsChanged,
            modifiers: .defaultSnap,
            location: CGPoint(x: 500, y: 400)
        )
        try await waitForCapture(windowController)
        eventSource.send(
            kind: .mouseMoved,
            modifiers: .defaultSnap,
            location: CGPoint(x: 530, y: 400)
        )
        controller.setSnapAnimationEnabled(false)
        eventSource.send(
            kind: .flagsChanged,
            modifiers: [],
            location: CGPoint(x: 530, y: 400)
        )

        try await waitForAppliedTransition(windowController)
        let appliedTransitions = await windowController.appliedTransitions()
        XCTAssertEqual(appliedTransitions, [.immediate])
    }

    func testRepeatedSystemInterruptionsResetActiveSnapPreviewAndAllowReentry() async throws {
        let (defaults, suiteName) = makeDefaults()
        let eventSource = SnapAnimationEventSource()
        let windowController = SnapAnimationWindowController()
        let preview = SnapAnimationPreviewDisplay()
        let controller = AppController(
            defaults: defaults,
            windowController: windowController,
            screenProvider: SnapAnimationScreenProvider(),
            eventSource: eventSource,
            previewController: preview,
            accessibilityTrust: { _ in true },
            accessibilityReduceMotion: { false }
        )
        defer {
            controller.shutdown()
            defaults.removePersistentDomain(forName: suiteName)
        }

        controller.start()
        try await waitForMonitoring(controller)

        for expectedCount in 1...2 {
            eventSource.send(
                kind: .flagsChanged,
                modifiers: .defaultSnap,
                location: CGPoint(x: 500, y: 400)
            )
            try await waitForCaptureCount(expectedCount, controller: windowController)
            try await waitForOriginMarkerCount(expectedCount, preview: preview)
            eventSource.send(
                kind: .mouseMoved,
                modifiers: .defaultSnap,
                location: CGPoint(x: 530, y: 400)
            )
            try await waitForPreviewCount(expectedCount, preview: preview)

            controller.handleSystemInterruption()

            XCTAssertFalse(preview.isVisible)
            XCTAssertFalse(preview.isOriginMarkerVisible)
            eventSource.send(
                kind: .flagsChanged,
                modifiers: [],
                location: CGPoint(x: 530, y: 400)
            )
        }

        XCTAssertEqual(preview.showCount, 2)
        XCTAssertEqual(preview.originMarkerShowCount, 2)
        XCTAssertEqual(preview.hideCount, 2)
        XCTAssertEqual(preview.invalidateCount, 2)
        XCTAssertEqual(controller.currentSnapTransition, .animated(.snapDefault))
        let appliedTransitions = await windowController.appliedTransitions()
        XCTAssertEqual(appliedTransitions, [])
    }

    func testSystemInterruptionClearsMarkerBeforeAnyLayoutIsSelected() async throws {
        let (defaults, suiteName) = makeDefaults()
        let eventSource = SnapAnimationEventSource()
        let windowController = SnapAnimationWindowController()
        let preview = SnapAnimationPreviewDisplay()
        let controller = AppController(
            defaults: defaults,
            windowController: windowController,
            screenProvider: SnapAnimationScreenProvider(),
            eventSource: eventSource,
            previewController: preview,
            accessibilityTrust: { _ in true },
            accessibilityReduceMotion: { false }
        )
        defer {
            controller.shutdown()
            defaults.removePersistentDomain(forName: suiteName)
        }

        controller.start()
        try await waitForMonitoring(controller)
        eventSource.send(
            kind: .flagsChanged,
            modifiers: .defaultSnap,
            location: CGPoint(x: 500, y: 400)
        )
        try await waitForOriginMarkerCount(1, preview: preview)

        XCTAssertTrue(preview.isOriginMarkerVisible)
        XCTAssertFalse(preview.isVisible)

        controller.handleSystemInterruption()

        XCTAssertFalse(preview.isOriginMarkerVisible)
        XCTAssertFalse(preview.isVisible)
        XCTAssertEqual(preview.showCount, 0)
        XCTAssertEqual(preview.hideCount, 1)
        XCTAssertEqual(preview.invalidateCount, 1)
        let appliedTransitions = await windowController.appliedTransitions()
        XCTAssertEqual(appliedTransitions, [])
    }

    func testSystemChangesDiscardBufferedGesturesAndAllowFreshGestures() async throws {
        for usesScreenChange in [false, true] {
            let (defaults, suiteName) = makeDefaults()
            let eventSource = SnapAnimationEventSource()
            let windowController = SnapAnimationWindowController()
            let screenProvider = SnapAnimationScreenProvider()
            let preview = SnapAnimationPreviewDisplay()
            let controller = AppController(
                defaults: defaults,
                windowController: windowController,
                screenProvider: screenProvider,
                eventSource: eventSource,
                previewController: preview,
                accessibilityTrust: { _ in true },
                accessibilityReduceMotion: { false }
            )
            defer {
                controller.shutdown()
                defaults.removePersistentDomain(forName: suiteName)
            }

            controller.start()
            try await waitForMonitoring(controller)
            let previousEpoch = eventSource.epoch

            if usesScreenChange {
                screenProvider.sendChange()
                for _ in 0..<300 {
                    if preview.invalidateCount == 1 { break }
                    try await Task.sleep(nanoseconds: 1_000_000)
                }
                XCTAssertEqual(preview.invalidateCount, 1)
            }

            // 系统中断前直接排队；屏幕变化则模拟变化前生成、之后才交付的旧输入。
            eventSource.send(
                kind: .flagsChanged,
                modifiers: .defaultSnap,
                location: CGPoint(x: 500, y: 400),
                sourceEpoch: previousEpoch
            )
            eventSource.send(
                kind: .mouseMoved,
                modifiers: .defaultSnap,
                location: CGPoint(x: 560, y: 400),
                sourceEpoch: previousEpoch
            )
            eventSource.send(
                kind: .flagsChanged,
                modifiers: [],
                location: CGPoint(x: 560, y: 400),
                sourceEpoch: previousEpoch
            )
            if !usesScreenChange {
                controller.handleSystemInterruption()
            }

            try await Task.sleep(nanoseconds: 50_000_000)
            let staleCaptures = await windowController.captureCount()
            let staleTransitions = await windowController.appliedTransitions()
            XCTAssertEqual(staleCaptures, 0)
            XCTAssertTrue(staleTransitions.isEmpty)
            XCTAssertTrue(controller.monitoringActive)

            eventSource.send(
                kind: .flagsChanged,
                modifiers: .defaultSnap,
                location: CGPoint(x: 500, y: 400)
            )
            try await waitForCapture(windowController)
            eventSource.send(
                kind: .mouseMoved,
                modifiers: .defaultSnap,
                location: CGPoint(x: 560, y: 400)
            )
            eventSource.send(
                kind: .flagsChanged,
                modifiers: [],
                location: CGPoint(x: 560, y: 400)
            )
            try await waitForAppliedTransition(windowController)
            let freshCaptures = await windowController.captureCount()
            let freshTransitions = await windowController.appliedTransitions()
            XCTAssertEqual(freshCaptures, 1)
            XCTAssertEqual(freshTransitions, [.animated(.snapDefault)])
        }
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "OrdoTests.SnapAnimation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: "ordo.onboarding.shown")
        return (defaults, suiteName)
    }

    private func waitForMonitoring(_ controller: AppController) async throws {
        for _ in 0..<300 {
            if controller.monitoringActive { return }
            await Task.yield()
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待窗口手势监听启动超时")
    }

    private func waitForCapture(_ controller: SnapAnimationWindowController) async throws {
        for _ in 0..<300 {
            if await controller.captureCount() == 1 { return }
            await Task.yield()
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待排布窗口捕获超时")
    }

    private func waitForCaptureCount(
        _ expectedCount: Int,
        controller: SnapAnimationWindowController
    ) async throws {
        for _ in 0..<300 {
            if await controller.captureCount() == expectedCount { return }
            await Task.yield()
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待第 \(expectedCount) 次排布窗口捕获超时")
    }

    private func waitForPreviewCount(
        _ expectedCount: Int,
        preview: SnapAnimationPreviewDisplay
    ) async throws {
        for _ in 0..<300 {
            if preview.showCount == expectedCount { return }
            await Task.yield()
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待第 \(expectedCount) 次排布预览显示超时")
    }

    private func waitForOriginMarkerCount(
        _ expectedCount: Int,
        preview: SnapAnimationPreviewDisplay
    ) async throws {
        for _ in 0..<300 {
            if preview.originMarkerShowCount == expectedCount { return }
            await Task.yield()
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待第 \(expectedCount) 次排布起点标记显示超时")
    }

    private func waitForAppliedTransition(
        _ controller: SnapAnimationWindowController
    ) async throws {
        for _ in 0..<300 {
            if await controller.appliedTransitions().count == 1 { return }
            await Task.yield()
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("等待排布提交超时")
    }
}

@MainActor
private final class SnapAnimationEventSource: EventSource {
    let events: AsyncStream<InputEvent>
    let failures: AsyncStream<EventSourceError>
    private let eventContinuation: AsyncStream<InputEvent>.Continuation
    private(set) var isRunning = false
    private(set) var epoch: UInt64 = 0
    private(set) var lastError: EventSourceError?
    private var timestamp: UInt64 = 0

    init() {
        let (events, eventContinuation) = AsyncStream<InputEvent>.makeStream()
        self.events = events
        self.eventContinuation = eventContinuation
        failures = AsyncStream { _ in }
    }

    func start() throws {
        guard !isRunning else { return }
        epoch &+= 1
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        epoch &+= 1
        isRunning = false
    }

    func send(
        kind: InputEventKind,
        modifiers: ModifierChord,
        location: CGPoint,
        sourceEpoch: UInt64? = nil
    ) {
        timestamp &+= 1
        eventContinuation.yield(
            InputEvent(
                kind: kind,
                modifiers: modifiers,
                location: location,
                timestamp: timestamp,
                sourceEpoch: sourceEpoch ?? epoch
            )
        )
    }
}

private actor SnapAnimationWindowController: WindowControlling {
    private var captures = 0
    private var transitions: [WindowFrameTransition] = []

    func captureWindow(at point: CGPoint, for mode: InteractionMode) async throws -> WindowSnapshot {
        captures += 1
        return WindowSnapshot(
            id: UUID(),
            frame: CGRect(x: 50, y: 50, width: 400, height: 300),
            pid: 1
        )
    }

    func currentFrame(of window: WindowSnapshot) async throws -> CGRect {
        window.frame
    }

    func raiseWindow(_ window: WindowSnapshot) async throws {}

    func setPosition(_ position: CGPoint, of window: WindowSnapshot) async throws -> WindowSnapshot {
        window
    }

    func setSize(_ size: CGSize, of window: WindowSnapshot) async throws -> WindowSnapshot {
        window
    }

    func applyFrame(
        _ frame: CGRect,
        to window: WindowSnapshot,
        transition: WindowFrameTransition
    ) async throws -> WindowSnapshot {
        transitions.append(transition)
        return WindowSnapshot(id: window.id, frame: frame, pid: window.pid)
    }

    func release(_ window: WindowSnapshot) async {}
    func releaseAll() async {}

    func captureCount() -> Int {
        captures
    }

    func appliedTransitions() -> [WindowFrameTransition] {
        transitions
    }
}

@MainActor
private final class SnapAnimationScreenProvider: ScreenGeometryProviding {
    private let changes: AsyncStream<[ScreenGeometry]>
    private let changeContinuation: AsyncStream<[ScreenGeometry]>.Continuation
    private let screen = ScreenGeometry(
        displayID: 1,
        frame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
        visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
        appKitFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
        appKitVisibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
        backingScaleFactor: 1,
        mainScreenFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
    )

    init() {
        let (changes, continuation) = AsyncStream<[ScreenGeometry]>.makeStream()
        self.changes = changes
        changeContinuation = continuation
        continuation.yield([screen])
    }

    func currentScreens() -> [ScreenGeometry] {
        [screen]
    }

    func screen(containingAXPoint point: CGPoint) -> ScreenGeometry? {
        screen
    }

    func screenAtPointer() -> ScreenGeometry? {
        screen
    }

    func screenChanges() -> AsyncStream<[ScreenGeometry]> {
        changes
    }

    func sendChange() {
        changeContinuation.yield([screen])
    }
}

@MainActor
private final class SnapAnimationPreviewDisplay: PreviewDisplaying {
    private(set) var showCount = 0
    private(set) var originMarkerShowCount = 0
    private(set) var hideCount = 0
    private(set) var invalidateCount = 0
    private(set) var isVisible = false
    private(set) var isOriginMarkerVisible = false

    func show(layout: SnapLayout, targetFrame: CGRect, screen: ScreenGeometry) {
        showCount += 1
        isVisible = true
    }

    func showOriginMarker(at location: CGPoint, screen: ScreenGeometry) {
        originMarkerShowCount += 1
        isOriginMarkerVisible = true
    }

    func hideLayout() {
        isVisible = false
    }

    func hide() {
        hideCount += 1
        isVisible = false
        isOriginMarkerVisible = false
    }

    func invalidate() {
        invalidateCount += 1
        isVisible = false
        isOriginMarkerVisible = false
    }
}
