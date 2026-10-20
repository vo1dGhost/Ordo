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
    static let contentSize = NSSize(width: 560, height: 500)

    static func apply(to window: NSWindow) {
        window.collectionBehavior.subtract([.canJoinAllSpaces, .fullScreenPrimary, .fullScreenAuxiliary, .fullScreenAllowsTiling])
        window.collectionBehavior.formUnion([.moveToActiveSpace, .fullScreenNone, .fullScreenDisallowsTiling])
        // 保留 SwiftUI 选择的 fullSizeContentView，让宿主继续计算标题栏安全区域。
        window.styleMask.remove(.resizable)
        window.tabbingMode = .disallowed
        if !(window.toolbar is MainWindowToolbar) {
            window.toolbar = MainWindowToolbar()
        }
        window.toolbarStyle = .expanded
        // 文字已经位于原生分段控件内，不再在下方重复显示工具栏标签。
        window.toolbar?.displayMode = .iconOnly
        window.titleVisibility = .visible
        // 标题栏与页面共用底色，只让分页胶囊保留独立的玻璃材质。
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = .windowBackgroundColor
        let currentContent = window.contentRect(forFrameRect: window.frame).size
        let titlebarInset = max(0, currentContent.height - window.contentLayoutRect.height)
        let fixedContent = NSSize(width: contentSize.width, height: contentSize.height + titlebarInset)
        window.contentMinSize = fixedContent
        window.contentMaxSize = fixedContent
        // 同时覆盖旧版恢复的窗口尺寸；工具栏与标题栏不占用页面的 500 pt。
        window.setContentSize(fixedContent)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }
}

@MainActor
final class MainWindowToolbar: NSToolbar, NSToolbarDelegate {
    private static let pagesIdentifier = NSToolbarItem.Identifier("Ordo.Pages")
    var onSelection: ((MainWindowPage) -> Void)?

    var selectedPage: MainWindowPage {
        get {
            let pages = MainWindowPage.allCases
            return pages.indices.contains(pageControl.selectedSegment) ? pages[pageControl.selectedSegment] : .basic
        }
        set {
            pageControl.selectedSegment = MainWindowPage.allCases.firstIndex(of: newValue) ?? 0
        }
    }

    private lazy var pageControl: NSSegmentedControl = {
        let control = MainWindowPageControl(
            labels: MainWindowPage.allCases.map(\.title),
            trackingMode: .selectOne,
            target: self,
            action: #selector(selectPage(_:))
        )
        control.selectedSegment = 0
        control.segmentStyle = .automatic
        if #available(macOS 26.0, *) {
            control.borderShape = .capsule
        }
        if #available(macOS 27.0, *) {
            control.role = .tabs
        }
        // 由 AppKit 决定玻璃材质、选中底色和辅助功能外观，旧系统沿用原生样式。
        control.setAccessibilityLabel("分页")
        control.setAccessibilityIdentifier("ordo.pages")
        for index in MainWindowPage.allCases.indices {
            control.setWidth(72, forSegment: index)
            control.setToolTip(MainWindowPage.allCases[index].title, forSegment: index)
        }
        control.sizeToFit()
        return control
    }()

    private lazy var pageItem: NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: Self.pagesIdentifier)
        item.label = "分页"
        item.paletteLabel = "分页"
        item.view = pageControl
        item.autovalidates = false
        return item
    }()

    init() {
        super.init(identifier: "Ordo.MainWindowPages")
        delegate = self
        displayMode = .iconOnly
        allowsUserCustomization = false
        autosavesConfiguration = false
        if #available(macOS 15.0, *) {
            allowsDisplayModeCustomization = false
        }
        centeredItemIdentifiers = [Self.pagesIdentifier]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.pagesIdentifier]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        itemIdentifier == Self.pagesIdentifier ? pageItem : nil
    }

    @objc private func selectPage(_ sender: NSSegmentedControl) {
        guard MainWindowPage.allCases.indices.contains(sender.selectedSegment) else { return }
        onSelection?(MainWindowPage.allCases[sender.selectedSegment])
    }
}

/// 焦点位于分页控件时，左右键与点击共用同一个选择入口。
@MainActor
private final class MainWindowPageControl: NSSegmentedControl {
    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty,
              event.keyCode == 123 || event.keyCode == 124 else {
            super.keyDown(with: event)
            return
        }
        let next = min(max(selectedSegment + (event.keyCode == 124 ? 1 : -1), 0), segmentCount - 1)
        guard next != selectedSegment else { return }
        selectedSegment = next
        if let action { sendAction(action, to: target) }
    }
}

@MainActor
struct MainWindowConfigurator: NSViewRepresentable {
    @ObservedObject var controller: AppController

    func makeNSView(context: Context) -> NSView {
        MainWindowObserverView(controller: controller)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? MainWindowObserverView)?.updateSelection()
    }
}

@MainActor
private final class MainWindowObserverView: NSView {
    private weak var observedWindow: NSWindow?
    private let controller: AppController

    init(controller: AppController) {
        self.controller = controller
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    func updateSelection() {
        guard let toolbar = window?.toolbar as? MainWindowToolbar else { return }
        toolbar.selectedPage = controller.mainWindowPage
        toolbar.onSelection = { [weak controller] page in controller?.mainWindowPage = page }
    }

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
        updateSelection()
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        MainWindowPresentation.shared.windowWillClose(window)
    }
}
