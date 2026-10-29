import SwiftUI

struct GestureSettingsView: View {
    @ObservedObject var controller: AppController
    var pressedModifiers: ModifierChord = []

    /// 输出卡片行，由功能页的分组卡片承载。
    var body: some View {
        ModifierChordPicker(
            title: "调整窗口大小",
            detail: "按住组合键并移动鼠标，控制窗口右下角。",
            identifier: "ordo.resizeChord",
            selection: $controller.resizeChord,
            pressedModifiers: pressedModifiers
        )
        Divider()
        ModifierChordPicker(
            title: "窗口排布",
            detail: "按住组合键，向八个方向移动鼠标，松键应用排布。",
            identifier: "ordo.snapChord",
            selection: $controller.snapChord,
            pressedModifiers: pressedModifiers
        )
        Divider()
        ModifierChordPicker(
            title: "移动窗口",
            detail: "按住组合键，窗口将跟随鼠标移动。",
            identifier: "ordo.moveChord",
            selection: $controller.moveChord,
            pressedModifiers: pressedModifiers
        )
    }
}
