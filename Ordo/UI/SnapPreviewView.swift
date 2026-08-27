import AppKit
import SwiftUI

struct SnapPreviewView: View {
    let layout: SnapLayout

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))

            Image(systemName: layout.previewSymbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .ordoGlassPanel(cornerRadius: 16)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(0.72), lineWidth: 2)
        }
        .padding(6)
        .opacity(isPresented ? 1 : 0)
        .scaleEffect(reduceMotion || isPresented ? 1 : 0.985)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("窗口排布预览")
        .accessibilityValue(layout.accessibilityTitle)
        .onAppear {
            if reduceMotion {
                isPresented = true
            } else {
                withAnimation(.easeOut(duration: 0.14)) {
                    isPresented = true
                }
            }
        }
    }
}

private extension SnapLayout {
    var accessibilityTitle: String {
        switch self {
        case .topLeft: "左上角"
        case .top: "铺满可见区域"
        case .topRight: "右上角"
        case .right: "右半屏"
        case .bottomRight: "右下角"
        case .bottom: "居中百分之六十"
        case .bottomLeft: "左下角"
        case .left: "左半屏"
        }
    }

    var previewSymbol: String {
        switch self {
        case .topLeft: "arrow.up.left"
        case .top: "arrow.up"
        case .topRight: "arrow.up.right"
        case .right: "arrow.right"
        case .bottomRight: "arrow.down.right"
        case .bottom: "arrow.down"
        case .bottomLeft: "arrow.down.left"
        case .left: "arrow.left"
        }
    }
}

private struct OrdoGlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            content
                .background(Color(nsColor: .windowBackgroundColor), in: shape)
                .overlay {
                    shape.stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
        } else if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape.stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
                }
        }
    }
}

extension View {
    func ordoGlassPanel(cornerRadius: CGFloat) -> some View {
        modifier(OrdoGlassPanelModifier(cornerRadius: cornerRadius))
    }
}
