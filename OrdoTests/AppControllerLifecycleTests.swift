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
        let logger = LifecycleActivityLogger()
        let controller = makeController(eventSource: eventSource, activityLogger: logger)

        controller.start()
        for _ in 0..<5 {
            controller.refreshPermissions()
        }

        let matchingErrors = logger.entries.filter {
            $0.level == .error
                && $0.category == .listener
                && $0.message == EventSourceError.eventTapCreationFailed.localizedDescription
        }
        XCTAssertEqual(matchingErrors.count, 1)
        XCTAssertEqual(eventSource.startCount, 6)
        cleanUp(controller)
    }

    func testFirstLaunchRequestsMainWindowOnlyOnceWithoutPrompting() {
        defaults.removeObject(forKey: "ordo.onboarding.shown")
        var prompts: [Bool] = []
        var presentationCount = 0
        let controller = makeController(
            eventSource: LifecycleEventSource(),
            accessibilityTrust: { prompt in
                prompts.append(prompt)
                return false
            }
        )
        controller.start()
        XCTAssertFalse(defaults.bool(forKey: "ordo.onboarding.shown"))

        controller.presentInitialWindowIfNeeded { presentationCount += 1 }
        controller.presentInitialWindowIfNeeded { presentationCount += 1 }
        controller.refreshPermissions()

        XCTAssertEqual(presentationCount, 1)
        XCTAssertTrue(defaults.bool(forKey: "ordo.onboarding.shown"))
        XCTAssertFalse(prompts.isEmpty)
        XCTAssertFalse(prompts.contains(true))
        cleanUp(controller)
    }

    func testExistingUserDoesNotReceiveAnotherInitialWindow() {
        let controller = makeController(eventSource: LifecycleEventSource())
        var presentationCount = 0
        controller.presentInitialWindowIfNeeded { presentationCount += 1 }
        XCTAssertEqual(presentationCount, 0)
        cleanUp(controller)
    }

    func testOnlyExplicitAuthorizationRequestsPermissionPrompt() {
        var prompts: [Bool] = []
        let controller = makeController(
            eventSource: LifecycleEventSource(),
            accessibilityTrust: { prompt in
                prompts.append(prompt)
                return false
            }
        )
        controller.start()
        controller.refreshPermissions()
        XCTAssertFalse(prompts.contains(true))
        controller.requestAccessibility()
        XCTAssertEqual(prompts.filter { $0 }.count, 1)
        cleanUp(controller)
    }

    func testSuccessfulActivitiesAreLoggedWithoutBecomingStatusMessages() {
        let logger = LifecycleActivityLogger()
        let controller = makeController(eventSource: LifecycleEventSource(), activityLogger: logger)
        controller.start()
        XCTAssertTrue(logger.entries.contains { $0.message == "Ordo 已启动" })
        XCTAssertNil(controller.statusMessage)
        controller.isEnabled = false
        XCTAssertTrue(logger.entries.contains { $0.message == "Ordo 已暂停" })
        XCTAssertNil(controller.statusMessage)
        cleanUp(controller)
    }

    func testListenerFailureStatusClearsAfterSuccessfulRecovery() {
        let source = LifecycleEventSource(startError: .eventTapCreationFailed)
        let controller = makeController(eventSource: source)
        controller.start()
        XCTAssertEqual(controller.statusMessage, EventSourceError.eventTapCreationFailed.localizedDescription)
        source.startError = nil
        controller.refreshPermissions()
        XCTAssertTrue(controller.isOperational)
        XCTAssertNil(controller.statusMessage)
        cleanUp(controller)
    }

    func testCorrectingShortcutsClearsConflictWhilePausedOrUnauthorized() {
        for isGranted in [false, true] {
            let controller = makeController(
                eventSource: LifecycleEventSource(),
                accessibilityTrust: { _ in isGranted }
            )
            controller.isEnabled = !isGranted
            controller.start()
            XCTAssertEqual(controller.accessibilityGranted, isGranted)
            controller.resizeChord = controller.moveChord
            XCTAssertNotNil(controller.shortcutValidationMessage)
            XCTAssertNotNil(controller.statusMessage)
            controller.resizeChord = .defaultResize
            XCTAssertNil(controller.shortcutValidationMessage)
            XCTAssertNil(controller.statusMessage)
            controller.shutdown()
        }
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testShutdownWaitsForBothWindowCleanupAndPendingLogWrites() async throws {
        let logger = LifecycleActivityLogger(blocksFinish: true)
        let windows = LifecycleWindowController(blocksReleaseAll: true)
        let controller = makeController(
            eventSource: LifecycleEventSource(),
            windowController: windows,
            activityLogger: logger
        )
        let shutdown = controller.shutdown()
        var completed = false
        let observer = Task { await shutdown.value; completed = true }
        for _ in 0..<300 {
            if await windows.releaseAllStarted(), logger.finishStarted { break }
            await Task.yield()
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(logger.finishStarted)
        await windows.resumeReleaseAll()
        for _ in 0..<10 { await Task.yield() }
        XCTAssertFalse(completed)
        logger.resumeFinish()
        await observer.value
        XCTAssertTrue(completed)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPermissionRefreshCannotRestartMonitoringDuringShutdown() async {
        let logger = LifecycleActivityLogger(blocksFinish: true)
        let source = LifecycleEventSource()
        let controller = makeController(eventSource: source, activityLogger: logger)
        controller.start()
        XCTAssertEqual(source.startCount, 1)
        let completion = controller.shutdown()
        controller.refreshPermissions()
        controller.isEnabled = false
        controller.isEnabled = true
        XCTAssertEqual(source.startCount, 1)
        XCTAssertFalse(controller.monitoringActive)
        XCTAssertFalse(source.isRunning)
        logger.resumeFinish()
        await completion.value
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testResetShortcutsRestoresAndPersistsDefaultsWithoutIntermediateConflicts() {
        defaults.set(Int(ModifierChord.defaultSnap.rawValue), forKey: "ordo.shortcut.resize")
        defaults.set(Int(ModifierChord.defaultMove.rawValue), forKey: "ordo.shortcut.snap")
        defaults.set(Int(ModifierChord.defaultResize.rawValue), forKey: "ordo.shortcut.move")
        let source = LifecycleEventSource()
        let logger = LifecycleActivityLogger()
        let controller = makeController(eventSource: source, activityLogger: logger)
        controller.start()
        let activityCount = logger.entries.count

        controller.resetShortcutsToDefaults()

        XCTAssertEqual(controller.resizeChord, .defaultResize)
        XCTAssertEqual(controller.snapChord, .defaultSnap)
        XCTAssertEqual(controller.moveChord, .defaultMove)
        XCTAssertNil(controller.shortcutValidationMessage)
        XCTAssertNil(controller.statusMessage)
        XCTAssertTrue(controller.isOperational)
        XCTAssertEqual(source.startCount, 1)
        XCTAssertEqual(logger.entries.count, activityCount)
        XCTAssertEqual(defaults.integer(forKey: "ordo.shortcut.resize"), Int(ModifierChord.defaultResize.rawValue))
        XCTAssertEqual(defaults.integer(forKey: "ordo.shortcut.snap"), Int(ModifierChord.defaultSnap.rawValue))
        XCTAssertEqual(defaults.integer(forKey: "ordo.shortcut.move"), Int(ModifierChord.defaultMove.rawValue))

        let reloaded = makeController(eventSource: LifecycleEventSource())
        XCTAssertEqual(reloaded.resizeChord, .defaultResize)
        XCTAssertEqual(reloaded.snapChord, .defaultSnap)
        XCTAssertEqual(reloaded.moveChord, .defaultMove)
        reloaded.shutdown()
        cleanUp(controller)
    }

    func testResetShortcutsClearsExistingConflictAndPreservesOtherSettings() {
        let controller = makeController(eventSource: LifecycleEventSource())
        controller.isEnabled = false
        controller.setSnapAnimationEnabled(false)
        controller.resizeChord = controller.moveChord
        XCTAssertNotNil(controller.shortcutValidationMessage)
        XCTAssertNotNil(controller.statusMessage)

        controller.resetShortcutsToDefaults()

        XCTAssertEqual(controller.resizeChord, .defaultResize)
        XCTAssertEqual(controller.snapChord, .defaultSnap)
        XCTAssertEqual(controller.moveChord, .defaultMove)
        XCTAssertNil(controller.shortcutValidationMessage)
        XCTAssertNil(controller.statusMessage)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertFalse(controller.isSnapAnimationEnabled)
        cleanUp(controller)
    }

    func testResetAlreadyDefaultShortcutsDoesNotRestartMonitoringOrLogWarnings() {
        let source = LifecycleEventSource()
        let logger = LifecycleActivityLogger()
        let controller = makeController(eventSource: source, activityLogger: logger)
        controller.start()
        let activityCount = logger.entries.count

        controller.resetShortcutsToDefaults()
        controller.resetShortcutsToDefaults()

        XCTAssertTrue(controller.isOperational)
        XCTAssertEqual(source.startCount, 1)
        XCTAssertEqual(logger.entries.count, activityCount)
        cleanUp(controller)
    }

    private func makeController(
        eventSource: LifecycleEventSource,
        windowController: LifecycleWindowController = LifecycleWindowController(),
        activityLogger: any ActivityLogging = LifecycleActivityLogger(),
        accessibilityTrust: @escaping @MainActor (_ prompt: Bool) -> Bool = { _ in true }
    ) -> AppController {
        AppController(
            defaults: defaults,
            windowController: windowController,
            screenProvider: LifecycleScreenProvider(),
            eventSource: eventSource,
            previewController: LifecyclePreviewDisplay(),
            activityLogger: activityLogger,
            accessibilityTrust: accessibilityTrust
        )
    }

    private func cleanUp(_ controller: AppController) {
        controller.shutdown()
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class LifecycleActivityLogger: ActivityLogging {
    private(set) var entries: [ActivityLogEntry] = []
    private(set) var finishStarted = false
    private let blocksFinish: Bool
    private var continuation: CheckedContinuation<Void, Never>?
    private var finishTask: Task<Void, Never>?
    private var hasResumed = false

    init(blocksFinish: Bool = false) {
        self.blocksFinish = blocksFinish
    }

    func append(_ entry: ActivityLogEntry) {
        entries.append(entry)
    }

    func finish() -> Task<Void, Never> {
        if let finishTask { return finishTask }
        finishStarted = true
        let task = Task {
            if blocksFinish, !hasResumed {
                await withCheckedContinuation { continuation = $0 }
            }
        }
        finishTask = task
        return task
    }

    func resumeFinish() {
        hasResumed = true
        continuation?.resume()
        continuation = nil
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
    var startError: EventSourceError?

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
