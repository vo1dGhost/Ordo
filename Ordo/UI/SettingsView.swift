import SwiftUI

struct GestureSettingsView: View {
    @ObservedObject var controller: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Form {
            Section {
                ModifierChordPicker(
                    title: "调整窗口大小",
                    detail: "按住组合键并移动鼠标，控制窗口右下角。",
                    selection: $controller.resizeChord
                )

                ModifierChordPicker(
                    title: "窗口排布",
                    detail: "按住组合键，以起点标记为参照向八个方向移动鼠标，选择排布。",
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
                Toggle(
                    isOn: Binding(
                        get: { controller.isSnapAnimationEnabled },
                        set: { controller.setSnapAnimationEnabled($0) }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("排布动画")
                        Text("松开组合键后，窗口平滑移动并调整到目标大小。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("排布效果")
            } footer: {
                if !controller.isSnapAnimationEnabled {
                    Text("动画已关闭，松开排布手势时窗口会立即到达目标位置和大小。")
                } else if reduceMotion {
                    Text("系统已开启“减少动态效果”，排布动画暂时停用。")
                } else {
                    Text("系统开启“减少动态效果”时，将暂时停用排布动画。")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("窗口手势")
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.18),
            value: controller.shortcutValidationMessage
        )
    }
}
