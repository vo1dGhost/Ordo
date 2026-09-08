import CoreGraphics
import Foundation
import XCTest
@testable import Ordo

@MainActor
final class AppControllerLifecycleTests: XCTestCase {
    private let suiteName = "OrdoTests.Lifecycle.\(UUID().uuidString)"
    private lazy var defaults: UserDefaults = {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: "ordo.onboarding.shown")
        return defaults
    }()

    func testShutdownTaskCompletesOnlyAfterWindowCleanupFinishes() async throws {
        let windowController = LifecycleWindowController(blocksReleaseAll: true)
        let controller = makeController(
            eventSource: LifecycleEventSource(),
            windowController: windowController
        )

        let shutdownTask = controller.shutdown()
        for _ in 0..<300 {
            if await windowController.releaseAllStarted() { break }
            await Task.yield()
            try await Task.sleep(nanoseconds: 1_000_000)
        }

        let started = await windowController.releaseAllStarted()
        let completedBeforeResume = await windowController.releaseAllCompleted()
        XCTAssertTrue(started)
        XCTAssertFalse(completedBeforeResume)

        await windowController.resumeReleaseAll()
        await shutdownTask.value

        let completed = await windowController.releaseAllCompleted()
        XCTAssertTrue(completed)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPermissionRecoveryRetriesPendingWindowCompatibilityRestoration() async throws {
        let eventSource = LifecycleEventSource()
        let windowController = LifecycleWindowController()
        let permission = LifecycleAccessibilityState(isGranted: false)
        let controller = makeController(
            eventSource: eventSource,
            windowController: windowController,
            accessibilityTrust: { _ in permission.isGranted }
        )
        controller.start()
        XCTAssertFalse(controller.accessibilityGranted)

        permission.isGranted = true
        controller.refreshPermissions()

        for _ in 0..<300 {
            if await windowController.permissionRecoveryCount() == 1 {
                break
            }
            await Task.yield()
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let recoveryCount = await windowController.permissionRecoveryCount()
        XCTAssertEqual(recoveryCount, 1)
        cleanUp(controller)
    }

    func testRepeatedListenerStartFailureIsLoggedOnlyOnce() {
        let eventSource = LifecycleEventSource(startError: .eventTapCreationFailed)
        let controller = makeController(eventSource: eventSource)

        controller.start()
        for _ in 0..<5 {
            controller.refreshPermissions()
        }

        let matchingErrors = controller.activityLog.filter {
            $0.level == .error
                && $0.category == .listener
                && $0.message == EventSourceError.eventTapCreationFailed.localizedDescription
        }
        XCTAssertEqual(matchingErrors.count, 1)
        XCTAssertEqual(eventSource.startCount, 6)
        cleanUp(controller)
    }

    private func makeController(
        eventSource: LifecycleEventSource,
        windowController: LifecycleWindowController = LifecycleWindowController(),
        accessibilityTrust: @escaping @MainActor (_ prompt: Bool) -> Bool = { _ in true }
    ) -> AppController {
        AppController(
            defaults: defaults,
            windowController: windowController,
            screenProvider: LifecycleScreenProvider(),
            eventSource: eventSource,
            previewController: LifecyclePreviewDisplay(),
            accessibilityTrust: accessibilityTrust
        )
    }

    private func cleanUp(_ controller: AppController) {
        controller.shutdown()
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class LifecycleAccessibilityState {
    var isGranted: Bool

    init(isGranted: Bool) {
        self.isGranted = isGranted
    }
}

@MainActor
private final class LifecycleEventSource: EventSource {
    let events = AsyncStream<InputEvent> { _ in }
    let failures = AsyncStream<EventSourceError> { _ in }
    private(set) var isRunning = false
    private(set) var epoch: UInt64 = 0
    private(set) var lastError: EventSourceError?
    private(set) var startCount = 0
    private let startError: EventSourceError?

    init(startError: EventSourceError? = nil) {
        self.startError = startError
    }

    func start() throws {
        guard !isRunning else { return }
        startCount += 1
        if let startError {
            lastError = startError
            throw startError
        }
        epoch &+= 1
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        epoch &+= 1
        isRunning = false
    }
}

private actor LifecycleWindowController: WindowControlling {
    private let blocksReleaseAll: Bool
    private var releaseAllIsStarted = false
    private var releaseAllIsCompleted = false
    private var releaseAllContinuation: CheckedContinuation<Void, Never>?
    private var permissionRecoveries = 0

    init(blocksReleaseAll: Bool = false) {
        self.blocksReleaseAll = blocksReleaseAll
    }

    func captureWindow(at point: CGPoint, for mode: InteractionMode) async throws -> WindowSnapshot {
        WindowSnapshot(id: UUID(), frame: .zero, pid: 1)
    }
    func currentFrame(of window: WindowSnapshot) async throws -> CGRect { window.frame }
    func raiseWindow(_ window: WindowSnapshot) async throws {}
    func setPosition(_ position: CGPoint, of window: WindowSnapshot) async throws -> WindowSnapshot { window }
    func setSize(_ size: CGSize, of window: WindowSnapshot) async throws -> WindowSnapshot { window }
    func applyFrame(
        _ frame: CGRect,
        to window: WindowSnapshot,
        transition: WindowFrameTransition
    ) async throws -> WindowSnapshot { window }
    func release(_ window: WindowSnapshot) async {}
    func accessibilityPermissionDidRecover() async {
        permissionRecoveries += 1
    }
    func releaseAll() async {
        releaseAllIsStarted = true
        if blocksReleaseAll {
            await withCheckedContinuation { continuation in
                releaseAllContinuation = continuation
            }
        }
        releaseAllIsCompleted = true
    }

    func releaseAllStarted() -> Bool {
        releaseAllIsStarted
    }

    func permissionRecoveryCount() -> Int {
        permissionRecoveries
    }

    func releaseAllCompleted() -> Bool {
        releaseAllIsCompleted
    }

    func resumeReleaseAll() {
        releaseAllContinuation?.resume()
        releaseAllContinuation = nil
    }
}

@MainActor
private final class LifecycleScreenProvider: ScreenGeometryProviding {
    func currentScreens() -> [ScreenGeometry] { [] }
    func screen(containingAXPoint point: CGPoint) -> ScreenGeometry? { nil }
    func screenAtPointer() -> ScreenGeometry? { nil }
    func screenChanges() -> AsyncStream<[ScreenGeometry]> {
        AsyncStream { continuation in
            continuation.yield([])
        }
    }
}

@MainActor
private final class LifecyclePreviewDisplay: PreviewDisplaying {
    func show(layout: SnapLayout, targetFrame: CGRect, screen: ScreenGeometry) {}
    func showOriginMarker(at location: CGPoint, screen: ScreenGeometry) {}
    func hideLayout() {}
    func hide() {}
}
