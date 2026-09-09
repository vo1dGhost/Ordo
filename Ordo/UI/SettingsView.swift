import SwiftUI

struct GestureSettingsView: View {
    @ObservedObject var controller: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            Section {
                ModifierChordPicker(
                    title: "调整窗口大小",
                    detail: "按住组合键并移动鼠标，控制窗口右下角。",
                    identifier: "ordo.resizeChord",
                    selection: $controller.resizeChord
                )

                ModifierChordPicker(
                    title: "窗口排布",
                    detail: "按住组合键，以起点标记为参照向八个方向移动鼠标，选择排布。",
                    identifier: "ordo.snapChord",
                    selection: $controller.snapChord
                )

                ModifierChordPicker(
                    title: "移动窗口",
                    detail: "按住组合键，窗口将跟随鼠标移动。",
                    identifier: "ordo.moveChord",
                    selection: $controller.moveChord
                )

                if let message = controller.shortcutValidationMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("快捷键设置错误：\(message)")
                        .accessibilityIdentifier("ordo.shortcutValidation")
                }
            } header: {
                HStack {
                    Text("手势快捷键")

                    Spacer()

                    Button("重置") {
                        controller.resetShortcutsToDefaults()
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("ordo.resetShortcuts")
                    .accessibilityHint("恢复默认组合键：调整大小 Option 和 Shift，排布 Command 和 Control，移动 Control 和 Shift")
                }
            }

            Section {
                Toggle(
                    isOn: Binding(
                        get: { controller.isSnapAnimationEnabled },
                        set: { controller.setSnapAnimationEnabled($0) }
                    )
                ) {
                    Text("排布动画")
                }
                .accessibilityIdentifier("ordo.snapAnimation")
                .accessibilityHint(
                    reduceMotion
                        ? "系统已开启减少动态效果，排布动画暂时停用"
                        : "启用后，松开组合键时窗口平滑移动并调整到目标大小"
                )
            } header: {
                Text("排布效果")
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.18),
            value: controller.shortcutValidationMessage
        )
    }
}
