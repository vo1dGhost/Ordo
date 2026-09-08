import CoreGraphics
import Foundation

/// 在 AX/Quartz 左上原点、Y 轴向下的全局坐标系中计算窗口布局。
enum LayoutEngine {
    static func targetFrame(for layout: SnapLayout, in visibleFrame: CGRect) -> CGRect {
        let frame = visibleFrame.standardized
        let halfWidth = frame.width / 2
        let halfHeight = frame.height / 2

        switch layout {
        case .topLeft:
            return CGRect(x: frame.minX, y: frame.minY, width: halfWidth, height: halfHeight)
        case .top:
            return frame
        case .topRight:
            return CGRect(x: frame.midX, y: frame.minY, width: halfWidth, height: halfHeight)
        case .right:
            return CGRect(x: frame.midX, y: frame.minY, width: halfWidth, height: frame.height)
        case .bottomRight:
            return CGRect(x: frame.midX, y: frame.midY, width: halfWidth, height: halfHeight)
        case .bottom:
            let width = frame.width * 0.75
            let height = frame.height * 0.75
            return CGRect(
                x: frame.midX - width / 2,
                y: frame.midY - height / 2,
                width: width,
                height: height
            )
        case .bottomLeft:
            return CGRect(x: frame.minX, y: frame.midY, width: halfWidth, height: halfHeight)
        case .left:
            return CGRect(x: frame.minX, y: frame.minY, width: halfWidth, height: frame.height)
        }
    }
}

/// AppKit 与 AX/Quartz 全局坐标之间的集中转换。
///
/// AppKit 的全局 Y 轴向上；Quartz 以主屏顶部为 Y=0 且向下增长。
enum ScreenCoordinateConverter {
    static func appKitToQuartz(_ point: CGPoint, mainScreenFrame: CGRect) -> CGPoint {
        CGPoint(x: point.x, y: mainScreenFrame.maxY - point.y)
    }

    static func quartzToAppKit(_ point: CGPoint, mainScreenFrame: CGRect) -> CGPoint {
        CGPoint(x: point.x, y: mainScreenFrame.maxY - point.y)
    }

    static func appKitToQuartz(_ rect: CGRect, mainScreenFrame: CGRect) -> CGRect {
        let rect = rect.standardized
        return CGRect(
            x: rect.minX,
            y: mainScreenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func quartzToAppKit(_ rect: CGRect, mainScreenFrame: CGRect) -> CGRect {
        let rect = rect.standardized
        return CGRect(
            x: rect.minX,
            y: mainScreenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}
