import AppKit
import SwiftUI

@main
struct OrdoApp: App {
    @NSApplicationDelegateAdaptor(OrdoAppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(controller: controller)
        } label: {
            Label(
                "Ordo",
                image: controller.isOperational
                    ? "MenuBarIconActive"
                    : "MenuBarIconInactive"
            )
            .accessibilityLabel(controller.isOperational ? "Ordo 正在运行" : "Ordo 未运行")
        }
        .menuBarExtraStyle(.menu)

        Window("Ordo", id: "main") {
            MainView(controller: controller)
                .frame(minWidth: 700, minHeight: 500)
        }
        .defaultSize(width: 780, height: 560)
        .windowResizability(.contentMinSize)
    }
}

@MainActor
final class OrdoAppDelegate: NSObject, NSApplicationDelegate {
    private var terminationPending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        AppController.shared.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        MainWindowPresentation.shared.applicationDidBecomeActive()
    }

    func applicationDidResignActive(_ notification: Notification) {
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
