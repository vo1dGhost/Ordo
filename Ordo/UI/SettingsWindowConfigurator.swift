import AppKit
import SwiftUI

@MainActor
final class MainWindowPresentation {
    static let shared = MainWindowPresentation()

    private enum Phase {
        case waitingForMenu
        case waitingForWindow
        case waitingForActivation
    }

    private weak var window: NSWindow?
    private var hasRequestedPresentation = false
    private var requestID = 0
    private var phase: Phase?
    private var expiresAt: TimeInterval = 0
    private let activateApplication: () -> Void
    private let isApplicationActive: () -> Bool
    private let enqueue: (@escaping @MainActor @Sendable () -> Void) -> Void
    private let now: () -> TimeInterval

    init(
        activateApplication: @escaping () -> Void = { NSApplication.shared.activate() },
        isApplicationActive: @escaping () -> Bool = { NSApplication.shared.isActive },
        enqueue: @escaping (@escaping @MainActor @Sendable () -> Void) -> Void = { action in
            // 默认模式在菜单 tracking 结束后执行，避免菜单收尾覆盖窗口前置。
            RunLoop.main.perform(inModes: [.default]) {
                MainActor.assumeIsolated { action() }
            }
        },
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.activateApplication = activateApplication
        self.isApplicationActive = isApplicationActive
        self.enqueue = enqueue
        self.now = now
    }

    static func open(using openWindow: OpenWindowAction) {
        shared.open { openWindow(id: "main") }
    }

    func open(openWindow: @escaping @MainActor @Sendable () -> Void) {
        cancel()
        hasRequestedPresentation = true
        phase = .waitingForMenu
        let id = requestID
        enqueue { [weak self] in
            guard let self, self.isCurrent(id) else { return }
            self.phase = .waitingForWindow
            self.expiresAt = self.now() + 2
            openWindow()
            self.enqueuePresentation(id)
        }
    }

    func register(_ window: NSWindow) {
        if self.window !== window, phase == .waitingForActivation {
            phase = .waitingForWindow
        }
        self.window = window
        MainWindowBehavior.apply(to: window)
        if !hasRequestedPresentation {
            window.orderOut(nil)
        }
        enqueuePresentation(requestID)
    }

    func unregister(_ window: NSWindow) {
        guard self.window === window else { return }
        self.window = nil
        if phase == .waitingForActivation {
            phase = .waitingForWindow
        }
    }

    func applicationDidBecomeActive() {
        guard phase == .waitingForActivation else { return }
        let id = requestID
        enqueue { [weak self] in self?.finishPresentation(id) }
    }

    func applicationDidResignActive() {
        // 菜单收尾可能先失去激活；尚未开始打开的用户请求仍需执行。
        guard phase != .waitingForMenu else { return }
        cancel()
    }

    func windowWillClose(_ window: NSWindow) {
        guard self.window === window else { return }
        // SwiftUI 可能保留并复用已关闭窗口，弱引用不在此处清空。
        cancel()
    }

    func cancel() {
        requestID += 1
        phase = nil
    }

    private func isCurrent(_ id: Int) -> Bool {
        guard requestID == id, phase != nil else { return false }
        if phase == .waitingForMenu { return true }
        guard now() < expiresAt else {
            cancel()
            return false
        }
        return true
    }

    private func enqueuePresentation(_ id: Int) {
        guard isCurrent(id) else { return }
        enqueue { [weak self] in self?.presentWindow(id) }
    }

    private func presentWindow(_ id: Int) {
        guard isCurrent(id), phase == .waitingForWindow, let window else { return }
        // AppKit 调用可能同步重入关闭或激活通知，先推进阶段，再逐步检查请求。
        phase = .waitingForActivation
        if window.isMiniaturized {
            window.deminiaturize(nil)
            guard isCurrent(id), self.window === window,
                  phase == .waitingForActivation else { return }
        }
        window.makeKeyAndOrderFront(nil)
        guard isCurrent(id), self.window === window,
              phase == .waitingForActivation else { return }
        // 用户明确打开时，在普通层级内前置一次，不依赖系统是否授予激活。
        window.orderFrontRegardless()
        guard isCurrent(id), self.window === window,
              phase == .waitingForActivation else { return }
        activateApplication()
        finishPresentation(id)
    }

    private func finishPresentation(_ id: Int) {
        guard isCurrent(id), phase == .waitingForActivation,
              isApplicationActive(), let window,
              window.isVisible, !window.isMiniaturized else { return }
        // 只收尾这次点击，之后的普通应用激活不得再次抢主窗口焦点。
        cancel()
        window.makeKeyAndOrderFront(nil)
    }
}

@MainActor
enum MainWindowBehavior {
    static func apply(to window: NSWindow) {
        window.collectionBehavior.remove(.canJoinAllSpaces)
        window.collectionBehavior.insert(.moveToActiveSpace)
        // 由系统工具栏布局标题，避免紧凑标题栏将原生标题固定在左侧。
        if !(window.toolbar is MainWindowTitleToolbar) {
            window.toolbar = MainWindowTitleToolbar(window: window)
        }
        window.toolbarStyle = .unifiedCompact
        window.titleVisibility = .hidden
    }
}

@MainActor
private final class MainWindowTitleToolbar: NSToolbar, NSToolbarDelegate {
    private let titleItem: NSToolbarItem
    private let titleLabel: NSTextField

    init(window: NSWindow) {
        titleItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("Ordo.WindowTitle"))
        titleLabel = NSTextField(labelWithString: window.title)
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.bind(.value, to: window, withKeyPath: "title", options: nil)
        titleItem.label = window.title
        titleItem.view = titleLabel
        super.init(identifier: "Ordo.MainWindowTitle")
        delegate = self
        centeredItemIdentifiers = [titleItem.itemIdentifier]
        displayMode = .iconOnly
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [titleItem.itemIdentifier]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [titleItem.itemIdentifier]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        itemIdentifier == titleItem.itemIdentifier ? titleItem : nil
    }
}

@MainActor
struct MainWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        MainWindowObserverView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

@MainActor
private final class MainWindowObserverView: NSView {
    private weak var observedWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let observedWindow {
            NotificationCenter.default.removeObserver(
                self, name: NSWindow.willCloseNotification, object: observedWindow
            )
            if observedWindow !== window {
                MainWindowPresentation.shared.unregister(observedWindow)
            }
        }
        observedWindow = window
        guard let window else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
        MainWindowPresentation.shared.register(window)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        MainWindowPresentation.shared.windowWillClose(window)
    }
}
