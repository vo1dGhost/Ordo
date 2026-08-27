import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Toggle(isOn: $controller.isEnabled) {
            Label("启用 Ordo", systemImage: controller.isEnabled ? "pause.circle" : "play.circle")
        }
        .accessibilityHint(controller.isEnabled ? "关闭窗口手势" : "启用窗口手势")

        Label(
            permissionTitle,
            systemImage: controller.accessibilityGranted
                ? "checkmark.shield.fill"
                : "exclamationmark.shield.fill"
        )
        .accessibilityLabel("辅助功能权限：\(permissionTitle)")

        if !controller.accessibilityGranted {
            Button {
                controller.requestAccessibility()
            } label: {
                Label("授权辅助功能…", systemImage: "hand.raised")
            }
            .accessibilityHint("显示 macOS 辅助功能授权提示")
        }

        Button {
            controller.refreshPermissions()
        } label: {
            Label("检查权限", systemImage: "arrow.clockwise")
        }

        if let message = controller.statusMessage {
            Divider()

            Button {
                controller.clearStatus()
            } label: {
                Label(message, systemImage: "info.circle")
            }
            .help("点击清除状态")
            .accessibilityLabel("最近状态：\(message)。点击清除")
        }

        Divider()

        SettingsLink {
            Label("设置…", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("退出 Ordo", systemImage: "power")
        }
        .keyboardShortcut("q", modifiers: .command)
        .accessibilityLabel("退出 Ordo")
    }

    private var permissionTitle: String {
        controller.accessibilityGranted ? "辅助功能已授权" : "需要辅助功能权限"
    }
}
