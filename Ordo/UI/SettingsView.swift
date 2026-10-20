import SwiftUI

struct GestureSettingsView: View {
    @ObservedObject var controller: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                ModifierChordPicker(
                    title: "调整窗口大小",
                    detail: "按住组合键并移动鼠标，控制窗口右下角。",
                    identifier: "ordo.resizeChord",
                    selection: $controller.resizeChord
                )
                ModifierChordPicker(
                    title: "窗口排布",
                    detail: "按住组合键，向八个方向移动鼠标，松键应用排布。",
                    identifier: "ordo.snapChord",
                    selection: $controller.snapChord
                )
                ModifierChordPicker(
                    title: "移动窗口",
                    detail: "按住组合键，窗口将跟随鼠标移动。",
                    identifier: "ordo.moveChord",
                    selection: $controller.moveChord
                )
            }

            Toggle("排布动画", isOn: Binding(
                get: { controller.isSnapAnimationEnabled },
                set: { controller.setSnapAnimationEnabled($0) }
            ))
            .toggleStyle(.switch)
            .accessibilityIdentifier("ordo.snapAnimation")
            .accessibilityHint(
                reduceMotion
                    ? "系统已开启减少动态效果，排布动画暂时停用"
                    : "启用后，松开组合键时窗口平滑移动并调整到目标大小"
            )
        }
    }
}
