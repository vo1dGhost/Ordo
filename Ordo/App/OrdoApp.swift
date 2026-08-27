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
                systemImage: controller.isOperational
                    ? "rectangle.3.group.fill"
                    : "rectangle.3.group"
            )
            .accessibilityLabel(controller.isOperational ? "Ordo 正在运行" : "Ordo 未运行")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(controller: controller)
        }
        .defaultSize(width: 560, height: 560)
    }
}

@MainActor
final class OrdoAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        AppController.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppController.shared.shutdown()
    }
}
