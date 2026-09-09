import SwiftUI

/// 首次使用与后续权限管理共用主窗口中的同一个区域。
struct AccessibilityPermissionSection: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Section {
            HStack {
                Label(
                    controller.accessibilityGranted ? "已授权" : "未授权",
                    systemImage: controller.accessibilityGranted
                        ? "checkmark.shield.fill"
                        : "exclamationmark.shield.fill"
                )
                .foregroundStyle(controller.accessibilityGranted ? .green : .orange)
                .accessibilityLabel(
                    controller.accessibilityGranted
                        ? "辅助功能权限已授权"
                        : "辅助功能权限未授权"
                )
                .accessibilityIdentifier("ordo.permissionStatus")

                Spacer()

                Button("重新检查") {
                    controller.refreshPermissions()
                }
                .accessibilityLabel("重新检查辅助功能权限")
                .accessibilityIdentifier("ordo.checkPermission")
            }

            if !controller.accessibilityGranted {
                Text("允许 Ordo 通过辅助功能权限移动和调整窗口。窗口手势只观察修饰键和鼠标，不读取或阻止普通按键输入。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("授权辅助功能") {
                    controller.requestAccessibility()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("显示 macOS 辅助功能授权提示")
                .accessibilityIdentifier("ordo.requestPermission")
            }
        } header: {
            Text("辅助功能权限")
        } footer: {
            if !controller.accessibilityGranted {
                Text("完全本地运行。只有点击授权按钮后，才会请求系统授权。")
            }
        }
    }
}
