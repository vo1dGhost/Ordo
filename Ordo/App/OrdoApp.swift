import AppKit
import SwiftUI

@main
struct OrdoApp: App {
    @NSApplicationDelegateAdaptor(OrdoAppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController.shared

    var body: some Scene {
        MenuBarExtra(isInserted: Binding(
            get: { controller.isMenuBarIconVisible },
            set: { controller.setMenuBarIconVisible($0) }
        )) {
            MenuBarContent(controller: controller)
        } label: {
            MenuBarStatusLabel(controller: controller)
        }
        .menuBarExtraStyle(.menu)

        MainWindowScene(controller: controller, appDelegate: appDelegate)
    }
}

private struct MainWindowScene: Scene {
    @ObservedObject var controller: AppController
    @ObservedObject var appDelegate: OrdoAppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Ordo", id: "main") {
            MainView(controller: controller)
        }
        .defaultSize(width: MainWindowBehavior.contentSize.width, height: MainWindowBehavior.contentSize.height)
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified(showsTitle: false))
        .onChange(of: appDelegate.mainWindowRequest, initial: true) { _, request in
            guard request > 0 else { return }
            controller.markMainWindowPresented()
            MainWindowPresentation.open(using: openWindow)
        }
    }
}

private struct MenuBarStatusLabel: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Label(
            "Ordo",
            image: controller.isOperational ? "MenuBarIconActive" : "MenuBarIconInactive"
        )
        .accessibilityLabel(controller.isOperational ? "Ordo 正在运行" : "Ordo 未运行")
    }
}

@MainActor
final class OrdoAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var mainWindowRequest = 0
    private var terminationPending = false
    private var hasHandledLaunch = false
    private let shouldPresentOnManualLaunch: @MainActor () -> Bool

    override convenience init() {
        self.init(shouldPresentOnManualLaunch: { AppController.shared.shouldShowMainWindowOnManualLaunch })
    }

    init(shouldPresentOnManualLaunch: @escaping @MainActor () -> Bool) {
        self.shouldPresentOnManualLaunch = shouldPresentOnManualLaunch
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !ActivityLoggerFactory.isRunningTests else {
            // 测试宿主不自动展示或监听，但允许测试随后显式重开自己的窗口。
            hasHandledLaunch = true
            return
        }
        NSApplication.shared.setActivationPolicy(.accessory)
        AppController.shared.start()
        handleLaunchEvent(NSAppleEventManager.shared().currentAppleEvent)
    }

    func handleLaunchEvent(_ event: NSAppleEventDescriptor?) {
        guard !hasHandledLaunch, !terminationPending else { return }
        hasHandledLaunch = true
        let launchSource = event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
        let isBackgroundLaunch = launchSource == keyAELaunchedAsLogInItem
            || launchSource == keyAELaunchedAsServiceItem
        if !isBackgroundLaunch, shouldPresentOnManualLaunch(), mainWindowRequest == 0 {
            mainWindowRequest += 1
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 启动通知之前的重开属于本次冷启动，由启动来源和静默偏好统一决定。
        guard hasHandledLaunch, !terminationPending else { return false }
        mainWindowRequest += 1
        // 所有显式打开都经过同一个展示入口，不能由系统另外恢复窗口。
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !ActivityLoggerFactory.isRunningTests else { return }
        AppController.shared.refreshLoginItemStatus()
        MainWindowPresentation.shared.applicationDidBecomeActive()
    }

    func applicationDidResignActive(_ notification: Notification) {
        guard !ActivityLoggerFactory.isRunningTests else { return }
        MainWindowPresentation.shared.applicationDidResignActive()
    }

    func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {
        guard !terminationPending else {
            return .terminateLater
        }

        terminationPending = true
        MainWindowPresentation.shared.cancel()
        let cleanupTask = AppController.shared.shutdown()
        Task { @MainActor in
            await cleanupTask.value
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
