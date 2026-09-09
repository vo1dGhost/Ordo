import SwiftUI

struct MainView: View {
    @ObservedObject var controller: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Form {
            Section("运行") {
                Toggle("启用窗口管理", isOn: $controller.isEnabled)
                    .accessibilityIdentifier("ordo.enabled")
                    .accessibilityHint("关闭后，Ordo 不再响应窗口手势")

                LabeledContent("当前状态") {
                    Label(operationalTitle, systemImage: operationalSymbol)
                        .foregroundStyle(operationalColor)
                        .accessibilityLabel("当前状态：\(operationalTitle)")
                        .accessibilityIdentifier("ordo.operationalStatus")
                }

                if let message = controller.statusMessage,
                   message != controller.shortcutValidationMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("运行提示：\(message)")
                            .accessibilityIdentifier("ordo.statusMessage")

                        Spacer(minLength: 0)

                        Button {
                            controller.clearStatus()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("关闭运行提示")
                        .accessibilityIdentifier("ordo.dismissStatus")
                    }
                }
            }

            AccessibilityPermissionSection(controller: controller)
            GestureSettingsView(controller: controller)
        }
        .formStyle(.grouped)
        .background(MainWindowConfigurator())
        .onAppear {
            controller.refreshPermissions()
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.18),
            value: controller.accessibilityGranted
        )
    }

    private var operationalTitle: String {
        if controller.isOperational {
            return "正在运行"
        }
        if !controller.isEnabled {
            return "已暂停"
        }
        if !controller.accessibilityGranted {
            return "等待授权"
        }
        if controller.shortcutValidationMessage != nil {
            return "快捷键需要调整"
        }
        return "监听未运行"
    }

    private var operationalSymbol: String {
        if controller.isOperational {
            return "checkmark.circle.fill"
        }
        if !controller.isEnabled {
            return "pause.circle.fill"
        }
        return "exclamationmark.circle.fill"
    }

    private var operationalColor: Color {
        if controller.isOperational {
            return .green
        }
        if !controller.isEnabled {
            return .secondary
        }
        return .orange
    }
}
