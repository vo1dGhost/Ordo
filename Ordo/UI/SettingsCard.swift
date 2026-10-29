import SwiftUI

/// 内容层使用不透明分组卡片，玻璃只留给分页胶囊和可交互控件。
/// 固定页面不能包含滚动区域，因此不使用 `Form(.grouped)`。
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { SettingsCardSurface() }
    }
}

/// macOS 26 起卡片圆角与窗口同心，较早系统使用固定连续圆角。
private struct SettingsCardSurface: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            surface(ConcentricRectangle(corners: .concentric(minimum: .fixed(12)), isUniform: true))
        } else {
            surface(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func surface(_ shape: some Shape) -> some View {
        shape
            .fill(.fill.quaternary)
            .overlay {
                shape.stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
            }
    }
}

/// 卡片中的单行：左侧标题与可选说明，右侧放置控件。
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var minHeight: CGFloat = 36
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .frame(minHeight: minHeight)
        .padding(.vertical, 4)
    }
}

/// 相邻玻璃按钮共享同一容器采样，旧系统退化为普通横排。
struct GlassButtonGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) { content }
            }
        } else {
            HStack(spacing: 8) { content }
        }
    }
}

extension View {
    /// macOS 26 使用系统玻璃按钮，较早系统保留标准边框按钮。
    @ViewBuilder
    func ordoGlassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else if prominent {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.bordered)
        }
    }
}
