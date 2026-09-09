import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var controller: AppController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle(isOn: $controller.isEnabled) {
            Label("启用", systemImage: controller.isEnabled ? "pause.circle" : "play.circle")
        }
        .accessibilityLabel("启用")
        .accessibilityHint(controller.isEnabled ? "关闭窗口手势" : "启用窗口手势")

        Divider()

        Button {
            MainWindowPresentation.open(using: openWindow)
        } label: {
            Label("打开", systemImage: "macwindow")
        }
        .keyboardShortcut(",", modifiers: .command)
        .accessibilityLabel("打开")
        .accessibilityHint("打开 Ordo 主界面")

        Divider()

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("退出", systemImage: "power")
        }
        .keyboardShortcut("q", modifiers: .command)
        .accessibilityLabel("退出")
    }
}
