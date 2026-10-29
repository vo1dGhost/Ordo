import AppKit
import ServiceManagement
import SwiftUI
import XCTest
@testable import Ordo

/// 直接测量测试宿主自己的内容区域，不依赖真实辅助功能授权。
@MainActor
enum MainWindowLayoutAssertions {
    static func assertSingleHeader(_ window: NSWindow, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(window.titleVisibility, .hidden, file: file, line: line)
        XCTAssertEqual(window.toolbarStyle, .unified, file: file, line: line)
        guard let pages = window.toolbar?.items.first?.view as? NSSegmentedControl,
              let close = window.standardWindowButton(.closeButton) else {
            XCTFail("主窗口缺少分页或关闭按钮", file: file, line: line)
            return
        }
        // 直接比较同一窗口坐标，避免仅隐藏标题文字却仍留下独立的一行。
        let pagesFrame = pages.convert(pages.bounds, to: nil)
        XCTAssertGreaterThan(pagesFrame.width, 0, file: file, line: line)
        if #available(macOS 26.0, *) {
            XCTAssertGreaterThanOrEqual(pagesFrame.height, 32, "分页应使用标准工具栏高度", file: file, line: line)
        }
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(type) else {
                XCTFail("主窗口缺少系统控制按钮", file: file, line: line)
                continue
            }
            let frame = button.convert(button.bounds, to: nil)
            XCTAssertEqual(pagesFrame.midY, frame.midY, accuracy: 1, file: file, line: line)
        }
        let topMargin = window.frame.height - pagesFrame.maxY
        let bottomMargin = pagesFrame.minY - window.contentLayoutRect.maxY
        XCTAssertGreaterThanOrEqual(topMargin, 6, file: file, line: line)
        XCTAssertGreaterThanOrEqual(bottomMargin, 6, file: file, line: line)
        XCTAssertEqual(topMargin, bottomMargin, accuracy: 1, file: file, line: line)
        let geometry = XCTAttachment(string: "分页：\(pagesFrame)；关闭按钮：\(close.convert(close.bounds, to: nil))；顶部留白：\(topMargin)；底部留白：\(bottomMargin)")
        geometry.name = "顶部控件几何"
        geometry.lifetime = .keepAlways
        XCTContext.runActivity(named: "校验标准高度和窗口按钮对齐") { $0.add(geometry) }
    }

    static func assertPageFits(_ window: NSWindow, controller: AppController, file: StaticString = #filePath, line: UInt = #line) {
        assertSingleHeader(window, file: file, line: line)
        guard let content = window.contentView else {
            XCTFail("主窗口缺少内容", file: file, line: line)
            return
        }
        let insets = content.safeAreaInsets
        let usableSize = NSSize(
            width: content.bounds.width - insets.left - insets.right,
            height: content.bounds.height - insets.top - insets.bottom
        )
        // 捕获 fullSizeContentView 被移除后，宿主仍占满标题栏却丢失安全区域的回归。
        XCTAssertEqual(usableSize.width, 560, accuracy: 0.5, file: file, line: line)
        XCTAssertEqual(usableSize.height, 476, accuracy: 0.5, file: file, line: line)
        XCTAssertFalse(containsScrollView(content), "固定页面不应包含滚动区域", file: file, line: line)

        let page: AnyView
        switch controller.mainWindowPage {
        case .basic: page = AnyView(BasicSettingsView(controller: controller))
        case .features: page = AnyView(FeatureSettingsView(controller: controller))
        case .about: page = AnyView(AboutView())
        }
        // 不套用主窗口的固定高度，独立测量实际页面在 28 pt 边距内所需的最小高度。
        let measurement = NSHostingView(rootView: page.frame(width: 504).fixedSize(horizontal: false, vertical: true))
        let needed = measurement.fittingSize
        print("ORDO_LAYOUT page=\(controller.mainWindowPage.rawValue) granted=\(controller.accessibilityGranted) size=\(needed)")
        XCTAssertGreaterThan(needed.height, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(needed.height, 420, "页面需要 \(needed.height) pt，高于可用内容区域", file: file, line: line)
        XCTAssertEqual(needed.width, 504, accuracy: 0.5, file: file, line: line)
    }

    private static func containsScrollView(_ view: NSView) -> Bool {
        view is NSScrollView || view.subviews.contains { containsScrollView($0) }
    }
}

@MainActor
final class MainWindowLayoutTests: XCTestCase {
    func testPermissionChangesPreserveFixedLayout() async throws {
        let fixture = LayoutFixture(granted: true, loginStatus: .notRegistered)
        fixture.controller.start()
        fixture.controller.mainWindowPage = .features
        var authorizedHeight: CGFloat?
        for granted in [true, false, true] {
            fixture.accessibilityGranted = granted
            fixture.controller.refreshPermissions()
            try await Task.sleep(for: .milliseconds(50))
            fixture.window.contentView?.layoutSubtreeIfNeeded()
            XCTAssertEqual(fixture.controller.accessibilityGranted, granted)
            XCTAssertEqual(fixture.window.contentLayoutRect.size, NSSize(width: 560, height: 476))
            let measurement = NSHostingView(rootView: FeatureSettingsView(controller: fixture.controller)
                .frame(width: 504).fixedSize(horizontal: false, vertical: true))
            XCTAssertLessThanOrEqual(measurement.fittingSize.height, 420)
            if granted {
                if let authorizedHeight {
                    XCTAssertEqual(measurement.fittingSize.height, authorizedHeight, accuracy: 0.5)
                } else {
                    authorizedHeight = measurement.fittingSize.height
                }
            } else {
                // 未授权时才插入整行权限内容；恢复授权后整行及分隔线一起移除。
                XCTAssertGreaterThanOrEqual(measurement.fittingSize.height - (authorizedHeight ?? 0), 44)
            }
            try attach(fixture.window, name: granted ? "权限变化－已授权" : "权限变化－未授权")
        }
        await fixture.close()
    }

    func testPagesAndErrorStatesStayWithinFixedContentBounds() async throws {
        let scenarios: [(String, MainWindowPage, Bool, SMAppService.Status, Bool, Bool)] = [
            ("基础", .basic, true, .notRegistered, false, false),
            ("基础－待批准", .basic, true, .requiresApproval, false, false),
            ("基础－注册失败", .basic, true, .notRegistered, true, false),
            ("功能－未授权", .features, false, .notRegistered, false, false),
            ("功能－运行中", .features, true, .notRegistered, false, false),
            ("功能－未授权与冲突", .features, false, .notRegistered, false, true),
            ("关于", .about, true, .notRegistered, false, false)
        ]
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            for (name, page, granted, loginStatus, loginFailure, conflict) in scenarios {
                let fixture = LayoutFixture(granted: granted, loginStatus: loginStatus)
                fixture.controller.start()
                fixture.controller.mainWindowPage = page
                if loginFailure {
                    fixture.loginItems.shouldFail = true
                    fixture.controller.setLaunchAtLoginEnabled(true)
                }
                if conflict { fixture.controller.resizeChord = fixture.controller.moveChord }
                let window = fixture.window
                window.appearance = NSAppearance(named: appearance)
                try await Task.sleep(for: .milliseconds(50))
                window.contentView?.superview?.layoutSubtreeIfNeeded()
                window.displayIfNeeded()
                XCTAssertEqual(window.contentLayoutRect.size, NSSize(width: 560, height: 476))
                MainWindowLayoutAssertions.assertPageFits(window, controller: fixture.controller)
                try attach(window, name: "\(name)－\(appearance.rawValue)")
                await fixture.close()
            }
        }
    }

    func testListenerFailureRemainsReadable() async throws {
        let fixture = LayoutFixture(granted: true, loginStatus: .notRegistered, listenerFails: true)
        fixture.controller.start()
        fixture.controller.mainWindowPage = .features
        try await Task.sleep(for: .milliseconds(50))
        fixture.window.contentView?.superview?.layoutSubtreeIfNeeded()
        fixture.window.displayIfNeeded()
        XCTAssertEqual(fixture.window.contentLayoutRect.size, NSSize(width: 560, height: 476))
        XCTAssertNotNil(fixture.controller.statusMessage)
        MainWindowLayoutAssertions.assertPageFits(fixture.window, controller: fixture.controller)
        try attach(fixture.window, name: "功能－监听失败")
        await fixture.close()
    }

    private func attach(_ window: NSWindow, name: String) throws {
        let view = try XCTUnwrap(window.contentView?.superview)
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(bitmap)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private final class LayoutFixture {
    private let trust: LayoutAccessibilityTrust
    var accessibilityGranted: Bool {
        get { trust.granted }
        set { trust.granted = newValue }
    }
    let suite = "OrdoTests.WindowLayout.\(UUID().uuidString)"
    let controller: AppController
    let loginItems: LayoutLoginItems
    let window: NSWindow

    init(granted: Bool, loginStatus: SMAppService.Status, listenerFails: Bool = false) {
        let trust = LayoutAccessibilityTrust(granted: granted)
        self.trust = trust
        let defaults = UserDefaults(suiteName: suite)!
        loginItems = LayoutLoginItems(status: loginStatus)
        controller = AppController(
            defaults: defaults,
            windowController: LayoutWindows(),
            screenProvider: LayoutScreens(),
            eventSource: LayoutEvents(shouldFail: listenerFails),
            previewController: LayoutPreview(),
            loginItemManager: loginItems,
            accessibilityTrust: { _ in trust.granted }
        )
        window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 560, height: 476),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Ordo 布局测试"
        window.contentViewController = NSHostingController(rootView: MainView(controller: controller))
        window.makeKeyAndOrderFront(nil)
    }

    func close() async {
        window.close()
        MainWindowPresentation.shared.unregister(window)
        await controller.shutdown().value
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }
}

@MainActor
private final class LayoutAccessibilityTrust {
    var granted: Bool
    init(granted: Bool) { self.granted = granted }
}

@MainActor
private final class LayoutLoginItems: LoginItemManaging {
    var status: SMAppService.Status
    var shouldFail = false
    init(status: SMAppService.Status) { self.status = status }
    func setEnabled(_ enabled: Bool) throws {
        if shouldFail {
            throw NSError(domain: "OrdoTests.Login", code: 1, userInfo: [NSLocalizedDescriptionKey: "登录项注册失败，请重新尝试。"])
        }
        status = enabled ? .enabled : .notRegistered
    }
    func openSystemSettings() {}
}

@MainActor
private final class LayoutEvents: EventSource {
    let events = AsyncStream<InputEventBatch> { _ in }
    let failures = AsyncStream<EventSourceError> { _ in }
    var isRunning = false
    var epoch: UInt64 = 0
    var lastError: EventSourceError?
    var onInterruption: (@MainActor () -> Void)?
    let shouldFail: Bool
    init(shouldFail: Bool) { self.shouldFail = shouldFail }
    func start() throws {
        if shouldFail { throw EventSourceError.eventTapCreationFailed }
        isRunning = true
        epoch &+= 1
    }
    func stop() { isRunning = false; epoch &+= 1 }
}

private actor LayoutWindows: WindowControlling {
    func captureWindow(at point: CGPoint, for mode: InteractionMode) async throws -> WindowSnapshot { WindowSnapshot(id: UUID(), frame: .zero, pid: 1) }
    func currentFrame(of window: WindowSnapshot) async throws -> CGRect { window.frame }
    func raiseWindow(_ window: WindowSnapshot) async throws {}
    func setPosition(_ position: CGPoint, of window: WindowSnapshot) async throws -> WindowSnapshot { window }
    func setSize(_ size: CGSize, of window: WindowSnapshot) async throws -> WindowSnapshot { window }
    func applyFrame(_ frame: CGRect, to window: WindowSnapshot, transition: WindowFrameTransition) async throws -> WindowSnapshot { window }
    func release(_ window: WindowSnapshot) async {}
    func releaseAll() async {}
}

@MainActor
private final class LayoutScreens: ScreenGeometryProviding {
    func currentScreens() -> [ScreenGeometry] { [] }
    func screen(containingAXPoint point: CGPoint) -> ScreenGeometry? { nil }
    func screenAtPointer() -> ScreenGeometry? { nil }
    func screenChanges() -> AsyncStream<[ScreenGeometry]> { AsyncStream { $0.finish() } }
}

@MainActor
private final class LayoutPreview: PreviewDisplaying {
    func show(layout: SnapLayout, targetFrame: CGRect, screen: ScreenGeometry) {}
    func showOriginMarker(at location: CGPoint, screen: ScreenGeometry) {}
    func hideLayout() {}
    func hide() {}
}
