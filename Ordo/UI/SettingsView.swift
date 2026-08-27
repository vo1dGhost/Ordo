import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Form {
            Section("运行") {
                Toggle("启用窗口管理", isOn: $controller.isEnabled)
                    .accessibilityHint("关闭后，Ordo 不再响应鼠标手势")

                LabeledContent("当前状态") {
                    Label(operationalTitle, systemImage: operationalSymbol)
                        .foregroundStyle(operationalColor)
                        .accessibilityLabel("当前状态：\(operationalTitle)")
                }
            }

            Section {
                ModifierChordPicker(
                    title: "调整窗口大小",
                    detail: "按住组合键并移动鼠标，控制窗口右下角。",
                    selection: $controller.resizeChord
                )

                ModifierChordPicker(
                    title: "窗口排布",
                    detail: "按住组合键并向八个方向轻摆鼠标，选择排布。",
                    selection: $controller.snapChord
                )

                ModifierChordPicker(
                    title: "移动窗口",
                    detail: "按住组合键，窗口将跟随鼠标移动。",
                    selection: $controller.moveChord
                )

                if let message = controller.shortcutValidationMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .accessibilityLabel("快捷键设置错误：\(message)")
                }
            } header: {
                Text("手势快捷键")
            } footer: {
                Text("每组快捷键至少包含两个修饰键，且三组组合不能重复。")
            }

            Section {
                LabeledContent("权限") {
                    Label(
                        controller.accessibilityGranted ? "已授权" : "未授权",
                        systemImage: controller.accessibilityGranted
                            ? "checkmark.circle.fill"
                            : "exclamationmark.circle.fill"
                    )
                    .foregroundStyle(controller.accessibilityGranted ? .green : .orange)
                    .accessibilityLabel(
                        controller.accessibilityGranted
                            ? "辅助功能权限已授权"
                            : "辅助功能权限未授权"
                    )
                }

                HStack {
                    if !controller.accessibilityGranted {
                        Button("授权辅助功能") {
                            controller.requestAccessibility()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("显示 macOS 辅助功能授权提示")
                    }

                    Button("重新检查") {
                        controller.refreshPermissions()
                    }
                    .accessibilityLabel("重新检查辅助功能权限")
                }
            } header: {
                Text("辅助功能权限")
            } footer: {
                Text("Ordo 仅使用辅助功能权限读写窗口位置与大小，不读取键盘输入。")
            }

            if let message = controller.statusMessage {
                Section("最近状态") {
                    HStack(alignment: .firstTextBaseline) {
                        Label(message, systemImage: "info.circle")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("清除") {
                            controller.clearStatus()
                        }
                        .buttonStyle(.link)
                        .accessibilityLabel("清除最近状态")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 500, idealHeight: 560)
        .onAppear {
            controller.refreshPermissions()
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.18),
            value: controller.shortcutValidationMessage
        )
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
