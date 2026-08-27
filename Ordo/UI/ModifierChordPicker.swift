import SwiftUI

struct ModifierChordPicker: View {
    let title: String
    let detail: String
    @Binding var selection: ModifierChord

    private var choices: [ModifierChoice] {
        [
            ModifierChoice(symbol: "⌘", name: "Command 键", chord: .command),
            ModifierChoice(symbol: "⌥", name: "Option 键", chord: .option),
            ModifierChoice(symbol: "⌃", name: "Control 键", chord: .control),
            ModifierChoice(symbol: "⇧", name: "Shift 键", chord: .shift)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)

                Spacer()

                Text(selection.displayString)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("当前组合：\(selection.displayString)")
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)

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
                    .accessibilityLabel(choice.name)
                    .accessibilityValue(selection.contains(choice.chord) ? "已选择" : "未选择")
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
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
    let symbol: String
    let name: String
    let chord: ModifierChord

    var id: String { name }
}
