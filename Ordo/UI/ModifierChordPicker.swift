import SwiftUI

struct ModifierChordPicker: View {
    let title: String
    let detail: String
    let identifier: String
    @Binding var selection: ModifierChord

    private var choices: [ModifierChoice] {
        [
            ModifierChoice(id: "command", symbol: "⌘", name: "Command 键", chord: .command),
            ModifierChoice(id: "option", symbol: "⌥", name: "Option 键", chord: .option),
            ModifierChoice(id: "control", symbol: "⌃", name: "Control 键", chord: .control),
            ModifierChoice(id: "shift", symbol: "⇧", name: "Shift 键", chord: .shift)
        ]
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 8) {
                ForEach(choices) { choice in
                    Toggle(
                        isOn: binding(for: choice.chord),
                        label: {
                            Text(choice.symbol)
                                .frame(minWidth: 22)
                        }
                    )
                    .toggleStyle(.button)
                    .controlSize(.regular)
                    .disabled(cannotRemove(choice.chord))
                    .help(choice.name)
                    .accessibilityLabel("\(title)：\(choice.name)")
                    .accessibilityValue(selection.contains(choice.chord) ? "已选择" : "未选择")
                    .accessibilityIdentifier("\(identifier).\(choice.id)")
                }
            }
        }
        .frame(minHeight: 30)
        .help(detail)
        .accessibilityElement(children: .contain)
        .accessibilityValue("当前组合：\(selection.displayString)")
        .accessibilityHint(detail)
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

private struct ModifierChoice: Identifiable {
    let id: String
    let symbol: String
    let name: String
    let chord: ModifierChord
}
