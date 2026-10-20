import SwiftUI

/// 首次使用与后续权限管理共用功能页，不自动触发系统授权提示。
struct AccessibilityPermissionSection: View {
    @ObservedObject var controller: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("辅助功能")
                Label(
                    controller.accessibilityGranted ? "已授权" : "未授权",
                    systemImage: controller.accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                )
                .font(.callout)
                .foregroundStyle(controller.accessibilityGranted ? .green : .orange)
                .accessibilityLabel(controller.accessibilityGranted ? "辅助功能权限已授权" : "辅助功能权限未授权")
                .accessibilityIdentifier("ordo.permissionStatus")

                Spacer()
                Button("重新检查") { controller.refreshPermissions() }
                    .accessibilityLabel("重新检查辅助功能权限")
                    .accessibilityIdentifier("ordo.checkPermission")
                if !controller.accessibilityGranted {
                    Button("授权") { controller.requestAccessibility() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("授权辅助功能")
                        .accessibilityHint("显示 macOS 辅助功能授权提示")
                        .accessibilityIdentifier("ordo.requestPermission")
                }
            }
            Text(controller.accessibilityGranted ? " " : "允许 Ordo 移动和调整窗口。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(controller.accessibilityGranted)
        }
    }
}
