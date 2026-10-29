import SwiftUI

struct ModifierChordPicker: View {
    let title: String
    let detail: String
    let identifier: String
    @Binding var selection: ModifierChord
    var pressedModifiers: ModifierChord = []

    private var choices: [ModifierChoice] {
        [
            // 对应键盘左下方的位置：Shift 在上方，其余三键从左到右排列。
            ModifierChoice(id: "shift", symbol: "⇧", name: "Shift 键", chord: .shift),
            ModifierChoice(id: "control", symbol: "⌃", name: "Control 键", chord: .control),
            ModifierChoice(id: "option", symbol: "⌥", name: "Option 键", chord: .option),
            ModifierChoice(id: "command", symbol: "⌘", name: "Command 键", chord: .command)
        ]
    }

    var body: some View {
        SettingsRow(title: title) {
            if #available(macOS 26.0, *) {
                // 同组键帽共享玻璃采样，选中态使用蓝色玻璃区分。
                GlassEffectContainer(spacing: 8) {
                    keys
                }
            } else {
                keys
            }
        }
        .help(detail)
        .accessibilityElement(children: .contain)
        .accessibilityValue("当前组合：\(selection.displayString)")
        .accessibilityHint(detail)
    }

    private var keys: some View {
        HStack(spacing: 8) {
            ForEach(choices) { choice in
                key(for: choice)
            }
        }
    }

    @ViewBuilder
    private func key(for choice: ModifierChoice) -> some View {
        let state = ModifierKeyDisplayState(key: choice.chord, selection: selection, pressed: pressedModifiers)
        let selectionValue = selection.contains(choice.chord) ? "已选择" : "未选择"
        let toggle = Toggle(
            isOn: binding(for: choice.chord),
            label: {
                Text(choice.symbol)
                    .frame(minWidth: 22)
            }
        )
        // 逐键指定颜色，禁止整行强调色将未选键一并染蓝。
        .tint(state.tint)
        .controlSize(.regular)
        .help(choice.name)
        .accessibilityLabel("\(title)：\(choice.name)")
        .accessibilityHint(cannotRemove(choice.chord) ? "组合至少需要两个修饰键；请先添加其他键再取消此键" : "切换此修饰键")
        .accessibilityValue(state == .pressed ? "已按下，\(selectionValue)" : selectionValue)
        .accessibilityIdentifier("\(identifier).\(choice.id)")
        toggle.toggleStyle(ModifierKeyToggleStyle(state: state))
    }

    private func binding(for chord: ModifierChord) -> Binding<Bool> {
        Binding(
            get: { selection.contains(chord) },
            set: { isSelected in
                var candidate = selection
                if isSelected {
                    candidate.insert(chord)
                } else {
                    candidate.remove(chord)
                }

                guard candidate.isValid else { return }
                selection = candidate
            }
        )
    }

    private func cannotRemove(_ chord: ModifierChord) -> Bool {
        guard selection.contains(chord) else { return false }
        var candidate = selection
        candidate.remove(chord)
        return !candidate.isValid
    }
}

/// 按住时绿色优先于蓝色选中态；较早系统使用标准边框按钮。
private struct ModifierKeyToggleStyle: ToggleStyle {
    let state: ModifierKeyDisplayState
    func makeBody(configuration: Configuration) -> some View {
        let button = Button { configuration.isOn.toggle() } label: { configuration.label }
        Group {
            if #available(macOS 26.0, *) {
                button
                    .buttonStyle(.glass)
                    .tint(state.tint)
                    .foregroundStyle(state == .idle ? Color.primary : Color.white)
                    .background {
                        if state != .idle { Capsule().fill(state.tint) }
                    }
            } else if state != .idle {
                button
                    .buttonStyle(.borderedProminent)
                    .tint(state.tint)
            } else {
                button
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

private struct ModifierChoice: Identifiable {
    let id: String
    let symbol: String
    let name: String
    let chord: ModifierChord
}
