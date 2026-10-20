import CoreGraphics
import Combine
import Foundation
import ServiceManagement
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

    func testPermissionPollingPublishesMonitoringOnlyWhenItChanges() {
        let source = LifecycleEventSource()
        let permission = LifecycleAccessibilityState(isGranted: true)
        let controller = makeController(
            eventSource: source,
            accessibilityTrust: { _ in permission.isGranted }
        )
        var states: [Bool] = []
        let observation = controller.$monitoringActive.dropFirst().sink { states.append($0) }
        defer { observation.cancel(); cleanUp(controller) }

        controller.start()
        for _ in 0..<5 { controller.refreshPermissions() }
        XCTAssertEqual(states, [true])
        XCTAssertEqual(source.startCount, 1)

        permission.isGranted = false
        controller.refreshPermissions()
        for _ in 0..<5 { controller.refreshPermissions() }
        XCTAssertEqual(states, [true, false])

        permission.isGranted = true
        controller.refreshPermissions()
        for _ in 0..<5 { controller.refreshPermissions() }
        XCTAssertEqual(states, [true, false, true])
        XCTAssertEqual(source.startCount, 2)
    }

    func testRepeatedListenerFailureDoesNotPublishUnchangedInactiveState() {
        let source = LifecycleEventSource(startError: .eventTapCreationFailed)
        let controller = makeController(eventSource: source)
        var states: [Bool] = []
        let observation = controller.$monitoringActive.dropFirst().sink { states.append($0) }
        defer { observation.cancel(); cleanUp(controller) }

        controller.start()
        for _ in 0..<5 { controller.refreshPermissions() }
        XCTAssertTrue(states.isEmpty)
        XCTAssertEqual(source.startCount, 6)
    }

    func testManualWindowOpeningMarksOnboardingWithoutPrompting() {
        defaults.removeObject(forKey: "ordo.onboarding.shown")
        var prompts: [Bool] = []
        let controller = makeController(
            eventSource: LifecycleEventSource(),
            accessibilityTrust: { prompt in
                prompts.append(prompt)
                return false
            }
        )
        controller.start()
        XCTAssertFalse(defaults.bool(forKey: "ordo.onboarding.shown"))

        controller.markMainWindowPresented()
        controller.markMainWindowPresented()
        controller.refreshPermissions()

        XCTAssertTrue(defaults.bool(forKey: "ordo.onboarding.shown"))
        XCTAssertFalse(prompts.isEmpty)
        XCTAssertFalse(prompts.contains(true))
        cleanUp(controller)
    }

    func testExistingOnboardingMarkerSurvivesStartupAndGestureReset() {
        let controller = makeController(eventSource: LifecycleEventSource())
        controller.start()
        controller.resizeChord = controller.moveChord
        controller.resetGestureSettingsToDefaults()
        XCTAssertTrue(defaults.bool(forKey: "ordo.onboarding.shown"))
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

        controller.resetGestureSettingsToDefaults()

        XCTAssertEqual(controller.resizeChord, .defaultResize)
        XCTAssertEqual(controller.snapChord, .defaultSnap)
        XCTAssertEqual(controller.moveChord, .defaultMove)
        XCTAssertNil(controller.shortcutValidationMessage)
        XCTAssertNil(controller.statusMessage)
        XCTAssertTrue(controller.isOperational)
        XCTAssertEqual(source.startCount, 2)
        XCTAssertEqual(logger.entries.count, activityCount + 1)
        XCTAssertTrue(logger.entries.allSatisfy { $0.level == .info })
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
        let loginItems = LifecycleLoginItems(status: .enabled)
        let controller = makeController(eventSource: LifecycleEventSource(), loginItemManager: loginItems)
        controller.isEnabled = false
        controller.setSnapAnimationEnabled(false)
        controller.setMenuBarIconVisible(false)
        controller.setSilentLaunchEnabled(true)
        controller.resizeChord = controller.moveChord
        XCTAssertNotNil(controller.shortcutValidationMessage)
        XCTAssertNotNil(controller.statusMessage)

        controller.resetGestureSettingsToDefaults()

        XCTAssertEqual(controller.resizeChord, .defaultResize)
        XCTAssertEqual(controller.snapChord, .defaultSnap)
        XCTAssertEqual(controller.moveChord, .defaultMove)
        XCTAssertNil(controller.shortcutValidationMessage)
        XCTAssertNil(controller.statusMessage)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertFalse(controller.isSnapAnimationEnabled)
        XCTAssertFalse(controller.isMenuBarIconVisible)
        XCTAssertTrue(controller.isSilentLaunchEnabled)
        XCTAssertTrue(controller.isLaunchAtLoginEnabled)
        XCTAssertTrue(loginItems.changes.isEmpty)
        cleanUp(controller)
    }

    func testResetAlreadyDefaultShortcutsDoesNotRestartMonitoringOrLogWarnings() {
        let source = LifecycleEventSource()
        let logger = LifecycleActivityLogger()
        let controller = makeController(eventSource: source, activityLogger: logger)
        controller.start()
        let activityCount = logger.entries.count

        controller.resetGestureSettingsToDefaults()
        controller.resetGestureSettingsToDefaults()

        XCTAssertTrue(controller.isOperational)
        XCTAssertEqual(source.startCount, 1)
        XCTAssertEqual(logger.entries.count, activityCount)
        cleanUp(controller)
    }

    func testResetPreservesLegacyDistanceForDowngrades() {
        defaults.set(80, forKey: "ordo.snap.triggerDistance")
        let controller = makeController(eventSource: LifecycleEventSource())
        controller.resetGestureSettingsToDefaults()
        XCTAssertEqual(defaults.double(forKey: "ordo.snap.triggerDistance"), 80)
        cleanUp(controller)
    }

    func testNewPreferencesDefaultAndPersistWithoutChangingMonitoring() {
        let source = LifecycleEventSource()
        let controller = makeController(eventSource: source)
        controller.start()
        XCTAssertTrue(controller.isMenuBarIconVisible)
        XCTAssertFalse(controller.isSilentLaunchEnabled)
        XCTAssertTrue(controller.shouldShowMainWindowOnManualLaunch)
        let epoch = source.epoch
        controller.setMenuBarIconVisible(false)
        controller.setSilentLaunchEnabled(true)
        XCTAssertFalse(controller.shouldShowMainWindowOnManualLaunch)
        XCTAssertEqual(source.epoch, epoch)
        XCTAssertTrue(controller.isOperational)

        let reloaded = makeController(eventSource: LifecycleEventSource())
        XCTAssertFalse(reloaded.isMenuBarIconVisible)
        XCTAssertTrue(reloaded.isSilentLaunchEnabled)
        XCTAssertFalse(reloaded.shouldShowMainWindowOnManualLaunch)
        controller.setMenuBarIconVisible(true)
        XCTAssertTrue(defaults.bool(forKey: "ordo.menuBar.visible"))
        reloaded.shutdown()
        cleanUp(controller)
    }

    func testRepeatedMenuBarBindingWritesDoNotRepublishState() {
        let controller = makeController(eventSource: LifecycleEventSource())
        var changes: [Bool] = []
        let observation = controller.$isMenuBarIconVisible.dropFirst().sink { changes.append($0) }
        controller.setMenuBarIconVisible(true)
        controller.setMenuBarIconVisible(false)
        controller.setMenuBarIconVisible(false)
        controller.setMenuBarIconVisible(true)
        controller.setMenuBarIconVisible(true)
        XCTAssertEqual(changes, [false, true])
        observation.cancel()
        cleanUp(controller)
    }

    func testFirstUseShowsWindowEvenWithSilentPreferenceAndSelectsPermissionPage() {
        let controller = makeController(
            eventSource: LifecycleEventSource(),
            accessibilityTrust: { _ in false }
        )
        defaults.removeObject(forKey: "ordo.onboarding.shown")
        controller.setSilentLaunchEnabled(true)
        XCTAssertTrue(controller.shouldShowMainWindowOnManualLaunch)
        controller.markMainWindowPresented()
        XCTAssertEqual(controller.mainWindowPage, .features)
        XCTAssertFalse(controller.shouldShowMainWindowOnManualLaunch)
        controller.mainWindowPage = .about
        controller.markMainWindowPresented()
        XCTAssertEqual(controller.mainWindowPage, .about)
        cleanUp(controller)
    }

    func testFirstAuthorizedPresentationSelectsBasicAndReopenKeepsSelection() {
        let controller = makeController(eventSource: LifecycleEventSource())
        controller.markMainWindowPresented()
        XCTAssertEqual(controller.mainWindowPage, .basic)
        controller.mainWindowPage = .features
        controller.markMainWindowPresented()
        XCTAssertEqual(controller.mainWindowPage, .features)
        cleanUp(controller)
    }

    func testRepeatedSilentPreferenceWritesDoNotRepublishOrRestartMonitoring() {
        let source = LifecycleEventSource()
        let controller = makeController(eventSource: source)
        controller.start()
        var changes: [Bool] = []
        let observation = controller.$isSilentLaunchEnabled.dropFirst().sink { changes.append($0) }
        controller.setSilentLaunchEnabled(false)
        controller.setSilentLaunchEnabled(true)
        controller.setSilentLaunchEnabled(true)
        controller.setSilentLaunchEnabled(false)
        XCTAssertEqual(changes, [true, false])
        XCTAssertEqual(source.startCount, 1)
        observation.cancel()
        cleanUp(controller)
    }

    func testLoginItemInitialStateAndExternalChangesNeverRegisterAutomatically() {
        let loginItems = LifecycleLoginItems()
        let controller = makeController(eventSource: LifecycleEventSource(), loginItemManager: loginItems)
        XCTAssertFalse(controller.isLaunchAtLoginEnabled)
        controller.start()
        for status: SMAppService.Status in [.enabled, .requiresApproval, .notRegistered, .notFound] {
            loginItems.status = status
            controller.refreshLoginItemStatus()
            XCTAssertEqual(controller.loginItemStatus, status)
            XCTAssertEqual(controller.isLaunchAtLoginEnabled, status == .enabled || status == .requiresApproval)
        }
        XCTAssertTrue(loginItems.changes.isEmpty)
        cleanUp(controller)
    }

    func testLoginItemRegistrationApprovalAndUnregistrationUseSystemState() {
        let loginItems = LifecycleLoginItems()
        loginItems.registrationStatus = .requiresApproval
        let controller = makeController(eventSource: LifecycleEventSource(), loginItemManager: loginItems)
        controller.setLaunchAtLoginEnabled(true)
        XCTAssertEqual(controller.loginItemStatus, .requiresApproval)
        XCTAssertTrue(controller.isLaunchAtLoginEnabled)
        controller.setLaunchAtLoginEnabled(true)
        XCTAssertEqual(loginItems.changes, [true])
        controller.openLoginItemSettings()
        XCTAssertEqual(loginItems.openSettingsCount, 1)
        loginItems.status = .enabled
        controller.refreshLoginItemStatus()
        XCTAssertEqual(controller.loginItemStatus, .enabled)
        controller.setLaunchAtLoginEnabled(false)
        controller.setLaunchAtLoginEnabled(false)
        XCTAssertEqual(controller.loginItemStatus, .notRegistered)
        XCTAssertEqual(loginItems.changes, [true, false])
        cleanUp(controller)
    }

    func testLoginItemErrorsPreserveActualStateAndRemainSeparateFromPermissionStatus() {
        let loginItems = LifecycleLoginItems()
        loginItems.failure = NSError(domain: "OrdoTests.LoginItem", code: 1)
        let controller = makeController(eventSource: LifecycleEventSource(), loginItemManager: loginItems)
        controller.setLaunchAtLoginEnabled(true)
        XCTAssertFalse(controller.isLaunchAtLoginEnabled)
        XCTAssertNotNil(controller.loginItemErrorMessage)
        XCTAssertNil(controller.statusMessage)
        loginItems.failure = nil
        controller.setLaunchAtLoginEnabled(true)
        XCTAssertTrue(controller.isLaunchAtLoginEnabled)
        XCTAssertNil(controller.loginItemErrorMessage)
        loginItems.failure = NSError(domain: "OrdoTests.LoginItem", code: 2)
        controller.setLaunchAtLoginEnabled(false)
        XCTAssertTrue(controller.isLaunchAtLoginEnabled)
        XCTAssertNotNil(controller.loginItemErrorMessage)
        loginItems.status = .notRegistered
        controller.refreshLoginItemStatus()
        XCTAssertNil(controller.loginItemErrorMessage)
        cleanUp(controller)
    }

    private func makeController(
        eventSource: LifecycleEventSource,
        windowController: LifecycleWindowController = LifecycleWindowController(),
        activityLogger: any ActivityLogging = LifecycleActivityLogger(),
        loginItemManager: any LoginItemManaging = LifecycleLoginItems(),
        accessibilityTrust: @escaping @MainActor (_ prompt: Bool) -> Bool = { _ in true }
    ) -> AppController {
        AppController(
            defaults: defaults,
            windowController: windowController,
            screenProvider: LifecycleScreenProvider(),
            eventSource: eventSource,
            previewController: LifecyclePreviewDisplay(),
            activityLogger: activityLogger,
            loginItemManager: loginItemManager,
            accessibilityTrust: accessibilityTrust
        )
    }

    private func cleanUp(_ controller: AppController) {
        controller.shutdown()
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class LifecycleLoginItems: LoginItemManaging {
    var status: SMAppService.Status
    var registrationStatus: SMAppService.Status = .enabled
    var failure: Error?
    var changes: [Bool] = []
    var openSettingsCount = 0

    init(status: SMAppService.Status = .notRegistered) {
        self.status = status
    }

    func setEnabled(_ enabled: Bool) throws {
        changes.append(enabled)
        if let failure { throw failure }
        status = enabled ? registrationStatus : .notRegistered
    }

    func openSystemSettings() {
        openSettingsCount += 1
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
    let events = AsyncStream<InputEventBatch> { _ in }
    let failures = AsyncStream<EventSourceError> { _ in }
    private(set) var isRunning = false
    private(set) var epoch: UInt64 = 0
    private(set) var lastError: EventSourceError?
    var onInterruption: (@MainActor () -> Void)?
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
