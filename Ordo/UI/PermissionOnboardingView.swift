import AppKit
import SwiftUI

struct PermissionOnboardingView: View {
    @ObservedObject var controller: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: controller.accessibilityGranted ? "checkmark.shield.fill" : "hand.raised.fill")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(controller.accessibilityGranted ? Color.green : Color.accentColor)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(controller.accessibilityGranted ? "Ordo 已准备就绪" : "允许 Ordo 管理窗口")
                    .font(.title2.weight(.semibold))

                Text(onboardingDescription)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                PermissionBenefitRow(
                    symbol: "rectangle.resize",
                    title: "调整大小与位置",
                    detail: "通过辅助功能 API 修改鼠标下方窗口的 frame。"
                )
                PermissionBenefitRow(
                    symbol: "keyboard.badge.ellipsis",
                    title: "普通模式不读取按键",
                    detail: "窗口手势只观察修饰键和鼠标，不读取或吞掉普通输入。"
                )
                PermissionBenefitRow(
                    symbol: "network.slash",
                    title: "完全本地运行",
                    detail: "没有网络请求，也不收集行为分析数据。"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                if controller.accessibilityGranted {
                    Button("完成") {
                        controller.dismissOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("授权辅助功能") {
                        controller.requestAccessibility()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityHint("显示 macOS 辅助功能授权提示")

                    Button("重新检查") {
                        controller.refreshPermissions()
                    }
                    .accessibilityLabel("重新检查辅助功能权限")
                }
            }
        }
        .padding(32)
        .frame(width: 440)
        .ordoGlassPanel(cornerRadius: 22)
        .padding(28)
        .frame(minWidth: 496, minHeight: 520)
        .onAppear {
            controller.refreshPermissions()
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.2),
            value: controller.accessibilityGranted
        )
        .accessibilityElement(children: .contain)
    }

    private var onboardingDescription: String {
        if controller.accessibilityGranted {
            return "辅助功能权限已授权。启用 Ordo 后即可使用三组鼠标手势。"
        }
        return "macOS 需要辅助功能权限，才能让 Ordo 移动和调整窗口。授权只会在你点击按钮后发起。"
    }
}

private struct PermissionBenefitRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
