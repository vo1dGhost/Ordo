import AppKit
import SwiftUI

struct SnapPreviewView: View {
    let layout: SnapLayout

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
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("窗口排布预览")
        .accessibilityValue(layout.accessibilityTitle)
    }
}

/// 以 Ordo 的八向分瓣环标识起点，中央留空，并同步当前布局方向。
struct SnapOriginMarkerView: View {
    static let size: CGFloat = 40

    let selectedLayout: SnapLayout?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        SnapOriginMarkerArtwork(
            selectedLayout: selectedLayout,
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency
        )
    }
}

/// 将系统辅助功能值作为绘制输入，便于在不修改系统设置的情况下核验各外观。
struct SnapOriginMarkerArtwork: View {
    let selectedLayout: SnapLayout?
    let reduceMotion: Bool
    let reduceTransparency: Bool

    private let iceBlue = Color(red: 0.56, green: 0.91, blue: 1)
    private let activeBlue = Color(red: 0.20, green: 0.79, blue: 1)

    var body: some View {
        marker
            .frame(width: SnapOriginMarkerView.size, height: SnapOriginMarkerView.size)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: selectedLayout)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var marker: some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            // 不合并相邻玻璃形状，保留八个方向之间的透明间隙。
            GlassEffectContainer(spacing: 0) {
                facets
            }
        } else {
            facets
        }
    }

    private var facets: some View {
        ZStack {
            ForEach(SnapLayout.allCases, id: \.self) { layout in
                let shape = SnapOriginMarkerFacet(layout: layout)
                let isSelected = selectedLayout == layout

                facetSurface(shape: shape, isSelected: isSelected)
                    .overlay {
                        shape.stroke(Color.black.opacity(0.55), lineWidth: 1.6)
                        shape.stroke(
                            Color.white.opacity(isSelected ? 1 : 0.72),
                            lineWidth: isSelected ? 1.15 : 0.55
                        )
                    }
                    .shadow(color: .black.opacity(0.28), radius: 0.8, y: 0.5)
            }
        }
    }

    @ViewBuilder
    private func facetSurface(shape: SnapOriginMarkerFacet, isSelected: Bool) -> some View {
        let tint = isSelected ? activeBlue : iceBlue

        if reduceTransparency {
            shape.fill(tint)
        } else {
            let surface = shape.fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isSelected ? 0.62 : 0.30),
                        tint.opacity(isSelected ? 0.85 : 0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            if #available(macOS 26.0, *) {
                surface.glassEffect(
                    .regular.tint(tint.opacity(isSelected ? 0.85 : 0.50)),
                    in: shape
                )
                .clipShape(shape)
                .overlay {
                    shape.fill(tint.opacity(isSelected ? 0.42 : 0.18))
                }
            } else {
                surface.background(.regularMaterial, in: shape)
            }
        }
    }
}

/// 单瓣路径以 40 pt 画布绘制，旋转后仍与实际八向布局一一对应。
struct SnapOriginMarkerFacet: Shape {
    let layout: SnapLayout

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16.9, y: 4))
        path.addLine(to: CGPoint(x: 23.1, y: 4))
        path.addQuadCurve(to: CGPoint(x: 23.96, y: 5.1), control: CGPoint(x: 24.24, y: 4))
        path.addLine(to: CGPoint(x: 22.6, y: 10.2))
        path.addQuadCurve(to: CGPoint(x: 21.6, y: 11), control: CGPoint(x: 22.4, y: 11))
        path.addLine(to: CGPoint(x: 18.4, y: 11))
        path.addQuadCurve(to: CGPoint(x: 17.4, y: 10.2), control: CGPoint(x: 17.6, y: 11))
        path.addLine(to: CGPoint(x: 16.04, y: 5.1))
        path.addQuadCurve(to: CGPoint(x: 16.9, y: 4), control: CGPoint(x: 15.76, y: 4))
        path.closeSubpath()

        let angle: CGFloat = switch layout {
        case .top: 0
        case .topRight: .pi / 4
        case .right: .pi / 2
        case .bottomRight: 3 * .pi / 4
        case .bottom: .pi
        case .bottomLeft: 5 * .pi / 4
        case .left: 3 * .pi / 2
        case .topLeft: 7 * .pi / 4
        }
        let scale = min(rect.width, rect.height) / 40
        let transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .rotated(by: angle)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -20, y: -20)
        return path.applying(transform)
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
        case .bottom: "居中百分之七十五"
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
