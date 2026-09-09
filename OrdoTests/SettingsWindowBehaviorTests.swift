import AppKit
import XCTest
@testable import Ordo

@MainActor
final class MainWindowBehaviorTests: XCTestCase {
    func testOpeningWaitsForMenuTurnAndWindowBeforeRequestingActivation() {
        let probe = PresentationProbe()
        probe.presentation.open { probe.openCount += 1 }

        XCTAssertEqual(probe.openCount, 0)
        XCTAssertEqual(probe.activationCount, 0)
        probe.drain()
        XCTAssertEqual(probe.openCount, 1)
        XCTAssertEqual(probe.activationCount, 0)

        probe.presentation.register(probe.window)
        XCTAssertEqual(probe.window.frontCount, 0)
        probe.drain()
        XCTAssertEqual(probe.activationCount, 1)
        XCTAssertEqual(probe.frontCountAtActivation, 1)
    }

    func testDelayedActivationFinishesOnlyTheExplicitPresentation() {
        let probe = PresentationProbe()
        probe.openRegisteredWindow()
        XCTAssertEqual(probe.window.frontCount, 1)

        probe.isActive = true
        probe.presentation.applicationDidBecomeActive()
        probe.drain()
        XCTAssertEqual(probe.window.frontCount, 2)

        probe.presentation.applicationDidBecomeActive()
        probe.drain()
        XCTAssertEqual(probe.window.frontCount, 2)
        XCTAssertEqual(probe.activationCount, 1)
        XCTAssertEqual(probe.window.regardlessFrontCount, 1)
    }

    func testRepeatedOpeningReusesWindowEvenAfterClosingIt() {
        let probe = PresentationProbe()
        probe.isActive = true
        probe.openRegisteredWindow()
        probe.presentation.windowWillClose(probe.window)
        probe.window.simulatedVisibility = false

        probe.presentation.open { probe.openCount += 1 }
        probe.drain()

        XCTAssertEqual(probe.openCount, 2)
        XCTAssertEqual(probe.activationCount, 2)
        XCTAssertEqual(probe.window.frontCount, 4)
        XCTAssertTrue(probe.window.isVisible)
    }

    func testReopeningAfterCloseAndSwitchingAppsOrdersInFrontWithoutActivation() {
        let probe = PresentationProbe()
        probe.isActive = true
        probe.openRegisteredWindow()
        XCTAssertTrue(probe.window.simulatedFrontmost)

        probe.presentation.windowWillClose(probe.window)
        probe.window.simulatedVisibility = false
        probe.window.simulatedFrontmost = false
        probe.isActive = false
        probe.presentation.applicationDidResignActive()

        // 模拟其他 App 仍在前台，系统未授予本次 activate 请求。
        probe.presentation.open { probe.openCount += 1 }
        probe.drain()

        XCTAssertFalse(probe.isActive)
        XCTAssertTrue(probe.window.isVisible)
        XCTAssertTrue(probe.window.simulatedFrontmost)
        XCTAssertEqual(probe.activationCount, 2)
        XCTAssertEqual(probe.window.regardlessFrontCount, 2)
        XCTAssertEqual(probe.window.level, .normal)
    }

    func testSwitchingAppsAfterCompletedOpeningDoesNotKeepWindowOnTop() {
        let probe = PresentationProbe()
        probe.isActive = true
        probe.openRegisteredWindow()
        XCTAssertTrue(probe.window.simulatedFrontmost)

        probe.isActive = false
        probe.window.simulatedFrontmost = false
        probe.presentation.applicationDidResignActive()
        probe.isActive = true
        probe.presentation.applicationDidBecomeActive()
        probe.drain()

        XCTAssertFalse(probe.window.simulatedFrontmost)
        XCTAssertEqual(probe.window.regardlessFrontCount, 1)
        XCTAssertEqual(probe.window.level, .normal)
    }

    func testRegistrationDuringOpeningDoesNotDuplicateActivation() {
        let probe = PresentationProbe()
        probe.presentation.open {
            probe.presentation.register(probe.window)
        }
        probe.drain()

        XCTAssertEqual(probe.window.frontCount, 1)
        XCTAssertEqual(probe.activationCount, 1)
    }

    func testRapidRequestsOnlyExecuteLatestOpening() {
        let probe = PresentationProbe()
        probe.presentation.register(probe.window)
        probe.presentation.open { XCTFail("旧请求不应再打开窗口") }
        probe.presentation.open { probe.openCount += 1 }
        probe.drain()

        XCTAssertEqual(probe.openCount, 1)
        XCTAssertEqual(probe.activationCount, 1)
    }

    func testAutomaticRegistrationDoesNotActivateOrShowWindow() {
        let probe = PresentationProbe()
        probe.presentation.register(probe.window)
        probe.presentation.applicationDidBecomeActive()
        probe.drain()

        XCTAssertEqual(probe.window.orderOutCount, 1)
        XCTAssertEqual(probe.window.frontCount, 0)
        XCTAssertEqual(probe.activationCount, 0)
        XCTAssertEqual(probe.window.regardlessFrontCount, 0)
    }

    func testExpiredRequestDoesNotPresentLateWindowOrReactToLaterActivation() {
        let probe = PresentationProbe()
        probe.presentation.open {}
        probe.drain()
        probe.time += 3
        probe.presentation.register(probe.window)
        probe.isActive = true
        probe.presentation.applicationDidBecomeActive()
        probe.drain()

        XCTAssertEqual(probe.window.frontCount, 0)
        XCTAssertEqual(probe.activationCount, 0)
        XCTAssertEqual(probe.window.regardlessFrontCount, 0)
    }

    func testClosingWindowCancelsQueuedActivationCompletion() {
        let probe = PresentationProbe()
        probe.openRegisteredWindow()
        probe.isActive = true
        probe.presentation.applicationDidBecomeActive()
        probe.presentation.windowWillClose(probe.window)
        probe.window.simulatedVisibility = false
        probe.drain()

        XCTAssertEqual(probe.window.frontCount, 1)
        XCTAssertFalse(probe.window.isVisible)
    }

    func testCancellationPreventsQueuedOpeningAndDelayedActivation() {
        let probe = PresentationProbe()
        probe.presentation.open { XCTFail("已取消的请求不应打开窗口") }
        probe.presentation.cancel()
        probe.drain()
        probe.openRegisteredWindow()
        probe.presentation.cancel()
        probe.isActive = true
        probe.presentation.applicationDidBecomeActive()
        probe.drain()

        XCTAssertEqual(probe.window.frontCount, 1)
    }

    func testMenuResigningBeforeDeferredOpenDoesNotDiscardUserRequest() {
        let probe = PresentationProbe()
        probe.presentation.register(probe.window)
        probe.presentation.open { probe.openCount += 1 }
        probe.presentation.applicationDidResignActive()
        probe.drain()

        XCTAssertEqual(probe.openCount, 1)
        XCTAssertEqual(probe.activationCount, 1)
    }

    func testSlowMenuDismissalDoesNotExpireExplicitOpening() {
        let probe = PresentationProbe()
        probe.presentation.register(probe.window)
        probe.presentation.open { probe.openCount += 1 }
        probe.time += 3
        probe.drain()

        XCTAssertEqual(probe.openCount, 1)
        XCTAssertEqual(probe.activationCount, 1)
    }

    func testDetachedWindowIsNotRevivedWhileWaitingForReplacement() {
        let probe = PresentationProbe()
        probe.presentation.register(probe.window)
        probe.presentation.unregister(probe.window)
        probe.presentation.open { probe.openCount += 1 }
        probe.drain()
        XCTAssertEqual(probe.window.frontCount, 0)
        XCTAssertEqual(probe.activationCount, 0)

        let replacement = PresentationWindow()
        probe.presentation.register(replacement)
        probe.drain()
        XCTAssertEqual(replacement.frontCount, 1)
        XCTAssertEqual(probe.activationCount, 1)
    }

    func testDetachingDuringFrontRequestWaitsForNewWindowBeforeActivation() {
        let probe = PresentationProbe()
        let replacement = PresentationWindow()
        probe.window.onFront = {
            probe.presentation.unregister(probe.window)
            probe.presentation.register(replacement)
        }
        probe.openRegisteredWindow()

        XCTAssertEqual(probe.window.frontCount, 1)
        XCTAssertEqual(replacement.frontCount, 1)
        XCTAssertEqual(probe.activationCount, 1)
    }

    func testActivationAfterDeadlineCannotRaiseWindowAgain() {
        let probe = PresentationProbe()
        probe.openRegisteredWindow()
        probe.time += 3
        probe.isActive = true
        probe.presentation.applicationDidBecomeActive()
        probe.drain()

        XCTAssertEqual(probe.window.frontCount, 1)
    }

    func testResigningAfterPresentationCancelsLateActivation() {
        let probe = PresentationProbe()
        probe.openRegisteredWindow()
        probe.presentation.applicationDidResignActive()
        probe.isActive = true
        probe.presentation.applicationDidBecomeActive()
        probe.drain()

        XCTAssertEqual(probe.window.frontCount, 1)
    }

    func testClosingAnotherWindowDoesNotCancelMainWindowPresentation() {
        let probe = PresentationProbe()
        probe.openRegisteredWindow()
        let otherWindow = PresentationWindow()
        probe.presentation.windowWillClose(otherWindow)
        probe.isActive = true
        probe.presentation.applicationDidBecomeActive()
        probe.drain()

        XCTAssertEqual(probe.window.frontCount, 2)
    }

    func testSynchronousCloseDuringFrontRequestPreventsActivation() {
        let probe = PresentationProbe()
        probe.window.onFront = {
            probe.presentation.windowWillClose(probe.window)
        }
        probe.openRegisteredWindow()

        XCTAssertEqual(probe.window.frontCount, 1)
        XCTAssertEqual(probe.activationCount, 0)
        XCTAssertEqual(probe.window.regardlessFrontCount, 0)
    }

    func testClosingDuringCrossApplicationOrderingPreventsActivation() {
        let probe = PresentationProbe()
        probe.window.onRegardlessFront = {
            probe.presentation.windowWillClose(probe.window)
            probe.window.simulatedVisibility = false
            probe.window.simulatedFrontmost = false
        }
        probe.openRegisteredWindow()
        probe.isActive = true
        probe.presentation.applicationDidBecomeActive()
        probe.drain()

        XCTAssertEqual(probe.window.regardlessFrontCount, 1)
        XCTAssertEqual(probe.activationCount, 0)
        XCTAssertFalse(probe.window.isVisible)
        XCTAssertFalse(probe.window.simulatedFrontmost)
    }

    func testSynchronousActivationNotificationOnlyCompletesOnce() {
        let probe = PresentationProbe()
        probe.onActivate = {
            probe.isActive = true
            probe.presentation.applicationDidBecomeActive()
        }
        probe.openRegisteredWindow()

        XCTAssertEqual(probe.window.frontCount, 2)
        XCTAssertEqual(probe.activationCount, 1)
    }

    func testMinimizedWindowIsRestoredBeforeActivationWithoutChangingLevel() {
        let probe = PresentationProbe()
        probe.window.simulatedMiniaturization = true
        probe.openRegisteredWindow()

        XCTAssertEqual(probe.window.deminiaturizeCount, 1)
        XCTAssertFalse(probe.window.isMiniaturized)
        XCTAssertEqual(probe.window.level, .normal)
        XCTAssertEqual(probe.frontCountAtActivation, 1)
    }

    func testApplyMovesWindowToActiveSpaceAndPreservesUnrelatedBehavior() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.collectionBehavior = [.canJoinAllSpaces, .managed, .fullScreenNone]

        MainWindowBehavior.apply(to: window)

        XCTAssertTrue(window.collectionBehavior.contains(.moveToActiveSpace))
        XCTAssertFalse(window.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(window.collectionBehavior.contains(.managed))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenNone))
    }

    func testApplyCentersTitleInSystemToolbarWithoutChangingWindowControlsOrLevel() throws {
        let styleMask: NSWindow.StyleMask = [
            .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView,
        ]
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 680),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = "Ordo"
        window.toolbar = NSToolbar(identifier: "OrdoTests.AutomaticToolbar")
        window.toolbarStyle = .unifiedCompact
        window.titleVisibility = .hidden

        MainWindowBehavior.apply(to: window)

        let toolbar = try XCTUnwrap(window.toolbar)
        let titleItem = try XCTUnwrap(toolbar.items.first)
        let titleLabel = try XCTUnwrap(titleItem.view as? NSTextField)
        XCTAssertEqual(toolbar.items.count, 1)
        XCTAssertEqual(toolbar.centeredItemIdentifiers, [titleItem.itemIdentifier])
        XCTAssertEqual(titleLabel.stringValue, "Ordo")
        XCTAssertFalse(titleLabel.isEditable)
        XCTAssertFalse(titleLabel.isBordered)
        XCTAssertEqual(window.toolbarStyle, .unifiedCompact)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertEqual(window.title, "Ordo")
        XCTAssertEqual(window.styleMask, styleMask)
        XCTAssertEqual(window.level, .normal)
        XCTAssertNotNil(window.standardWindowButton(.closeButton))
        XCTAssertNotNil(window.standardWindowButton(.miniaturizeButton))
        XCTAssertNotNil(window.standardWindowButton(.zoomButton))
        XCTAssertFalse(window.isVisible)
    }

    func testRepeatedTitleConfigurationReusesToolbarAndPreservesCurrentWindowTitle() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 680),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ordo"
        MainWindowBehavior.apply(to: window)
        let toolbar = try XCTUnwrap(window.toolbar)

        window.title = "Ordo 测试窗口"
        XCTAssertEqual((toolbar.items.first?.view as? NSTextField)?.stringValue, "Ordo 测试窗口")
        MainWindowBehavior.apply(to: window)
        MainWindowBehavior.apply(to: window)

        XCTAssertTrue(window.toolbar === toolbar)
        XCTAssertEqual(toolbar.items.count, 1)
        XCTAssertEqual((toolbar.items.first?.view as? NSTextField)?.stringValue, "Ordo 测试窗口")
        XCTAssertEqual(window.title, "Ordo 测试窗口")
        XCTAssertFalse(window.isVisible)
    }
}

@MainActor
private final class PresentationProbe {
    let window = PresentationWindow()
    var isActive = false {
        didSet { window.applicationIsActive = isActive }
    }
    var time: TimeInterval = 0
    var openCount = 0
    var activationCount = 0
    var frontCountAtActivation = 0
    var onActivate: (() -> Void)?
    private var operations: [@MainActor @Sendable () -> Void] = []

    lazy var presentation = MainWindowPresentation(
        activateApplication: { [unowned self] in
            activationCount += 1
            frontCountAtActivation = window.frontCount
            onActivate?()
        },
        isApplicationActive: { [unowned self] in isActive },
        enqueue: { [unowned self] in operations.append($0) },
        now: { [unowned self] in time }
    )

    func openRegisteredWindow() {
        presentation.register(window)
        presentation.open { [self] in openCount += 1 }
        drain()
    }

    func drain() {
        // 使用确定性的事件队列，测试不激活 App，也不显示真实窗口。
        for _ in 0..<20 {
            guard !operations.isEmpty else { return }
            operations.removeFirst()()
        }
        XCTFail("窗口展示不应产生无限重试")
    }
}

@MainActor
private final class PresentationWindow: NSWindow {
    var frontCount = 0
    var regardlessFrontCount = 0
    var orderOutCount = 0
    var deminiaturizeCount = 0
    var simulatedVisibility = false
    var simulatedFrontmost = false
    var simulatedMiniaturization = false
    var applicationIsActive = false
    var onFront: (() -> Void)?
    var onRegardlessFront: (() -> Void)?

    init() {
        super.init(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
    }

    override var isVisible: Bool { simulatedVisibility }
    override var isMiniaturized: Bool { simulatedMiniaturization }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        frontCount += 1
        simulatedVisibility = true
        // 普通前置不能保证越过另一 App 的 key window。
        simulatedFrontmost = applicationIsActive
        onFront?()
    }

    override func orderFrontRegardless() {
        regardlessFrontCount += 1
        simulatedVisibility = true
        simulatedFrontmost = true
        onRegardlessFront?()
    }

    override func orderOut(_ sender: Any?) {
        orderOutCount += 1
        simulatedVisibility = false
        simulatedFrontmost = false
    }

    override func deminiaturize(_ sender: Any?) {
        deminiaturizeCount += 1
        simulatedMiniaturization = false
    }
}
