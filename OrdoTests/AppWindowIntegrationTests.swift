import AppKit
import SwiftUI
import XCTest
@testable import Ordo

/// 只操作 XCTest 宿主自己的 SwiftUI 窗口；偏好、日志和全局监听均已隔离。
@MainActor
final class AppWindowIntegrationTests: XCTestCase {
    func testBackgroundLaunchDoesNotPresentMainWindow() async throws {
        try await Task.sleep(for: .milliseconds(50))
        if ProcessInfo.processInfo.arguments.contains("-ordo.menuBar.visible") {
            XCTAssertFalse(AppController.shared.isMenuBarIconVisible)
        }
        XCTAssertFalse(mainWindows.contains { $0.isVisible })
        XCTAssertFalse(AppController.shared.monitoringActive)
    }

    func testHiddenMenuBarReopensSwiftUIWindowAfterClosingAndKeepsSingleInstance() async throws {
        let controller = AppController.shared
        controller.setMenuBarIconVisible(false)
        controller.setSilentLaunchEnabled(true)
        defer {
            for window in mainWindows { window.close() }
            controller.setMenuBarIconVisible(true)
            controller.setSilentLaunchEnabled(false)
            UserDefaults(suiteName: AppController.testHostPreferenceSuiteName)?
                .removePersistentDomain(forName: AppController.testHostPreferenceSuiteName)
        }
        try await Task.sleep(for: .milliseconds(30))
        for window in mainWindows { window.close() }
        requestReopen()
        let first = try await waitForVisibleMainWindow()
        XCTAssertEqual(mainWindows.count, 1)
        XCTAssertFalse(controller.isMenuBarIconVisible)
        XCTAssertFalse(controller.monitoringActive)
        let initialSize = first.frame.size
        XCTAssertEqual(first.contentLayoutRect.size, NSSize(width: 560, height: 476))
        XCTAssertFalse(first.styleMask.contains(.resizable))
        XCTAssertEqual(controller.mainWindowPage, .features)
        let toolbar = try XCTUnwrap(first.toolbar as? MainWindowToolbar)
        let control = try XCTUnwrap(toolbar.items.first?.view as? NSSegmentedControl)
        for (index, page) in MainWindowPage.allCases.enumerated() {
            control.selectedSegment = index
            let action = try XCTUnwrap(control.action)
            XCTAssertTrue(control.sendAction(action, to: control.target))
            try await Task.sleep(for: .milliseconds(30))
            XCTAssertEqual(controller.mainWindowPage, page)
            XCTAssertEqual(toolbar.selectedPage, page)
            XCTAssertEqual(first.frame.size, initialSize)
            XCTAssertTrue(first.titlebarAppearsTransparent)
            XCTAssertEqual(first.titlebarSeparatorStyle, .none)
            XCTAssertNil(first.contentView.flatMap { firstScrollView(in: $0) })
            MainWindowLayoutAssertions.assertPageFits(first, controller: controller)
            try attachWindowContent(first, name: "固定主窗口－\(page.title)")
        }
        // 可选的本机目视验收窗口；仍使用隔离偏好，且禁止真实事件监听。
        // TEST_RUNNER_ORDO_UI_REVIEW=1 会由 xcodebuild 转发到测试宿主。
        if ProcessInfo.processInfo.environment["ORDO_UI_REVIEW"] == "1" {
            print("ORDO_UI_REVIEW_READY")
            try await Task.sleep(for: .seconds(90))
            controller.mainWindowPage = .about
        }
        first.close()
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertFalse(first.isVisible)
        requestReopen()
        let reopened = try await waitForVisibleMainWindow()
        XCTAssertTrue(first === reopened)
        XCTAssertEqual(controller.mainWindowPage, .about)
        XCTAssertEqual(reopened.frame.size, initialSize)
        MainWindowLayoutAssertions.assertSingleHeader(reopened)
        XCTAssertEqual(mainWindows.count, 1)
        XCTAssertFalse(controller.isMenuBarIconVisible)
        requestReopen()
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(mainWindows.count, 1)
    }

    func testMenuItemsHaveIconsAndNoKeyboardShortcuts() throws {
        guard #available(macOS 14.4, *) else {
            throw XCTSkip("NSHostingMenu 需要 macOS 14.4")
        }
        // 旧版 macOS 的菜单默认只显示文字，菜单项必须明确覆盖该样式。
        let menu = NSHostingMenu(rootView: MenuBarContent(controller: .shared).labelStyle(.titleOnly))
        menu.update()
        let commands = menu.items.filter { !$0.isSeparatorItem }
        XCTAssertEqual(commands.map(\.title), ["打开", "退出"])
        for item in commands {
            XCTAssertNotNil(item.image, "\(item.title) 应显示功能图标")
            XCTAssertEqual(item.keyEquivalent, "")
        }
    }

    private var mainWindows: [NSWindow] {
        NSApplication.shared.windows.filter { $0.title == "Ordo" }
    }

    private func requestReopen() {
        let result = NSApplication.shared.delegate?.applicationShouldHandleReopen?(
            NSApplication.shared, hasVisibleWindows: mainWindows.contains { $0.isVisible }
        )
        XCTAssertEqual(result, false)
    }

    private func waitForVisibleMainWindow() async throws -> NSWindow {
        for _ in 0..<200 {
            if let window = mainWindows.first(where: { $0.isVisible }) { return window }
            try await Task.sleep(for: .milliseconds(10))
        }
        return try XCTUnwrap(mainWindows.first(where: { $0.isVisible }), "隐藏菜单栏后仍应通过应用重开事件打开主窗口")
    }

    private func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView { return scrollView }
        return view.subviews.lazy.compactMap { self.firstScrollView(in: $0) }.first
    }

    private func attachWindowContent(_ window: NSWindow, name: String) throws {
        // 连同系统标题栏与原生分页工具栏一起留存，便于检查玻璃选中效果。
        let view = try XCTUnwrap(window.contentView?.superview)
        view.layoutSubtreeIfNeeded()
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
