import CoreGraphics
import Foundation

/// 移动和右下角缩放所需的无副作用几何计算。
enum WindowFrameCalculator {
    static func movedFrame(
        initialFrame: CGRect,
        from startMouseLocation: CGPoint,
        to currentMouseLocation: CGPoint
    ) -> CGRect {
        initialFrame.offsetBy(
            dx: currentMouseLocation.x - startMouseLocation.x,
            dy: currentMouseLocation.y - startMouseLocation.y
        )
    }

    /// 固定窗口左上角，使用鼠标相对位移改变右下角。
    static func resizedFrame(
        initialFrame: CGRect,
        from startMouseLocation: CGPoint,
        to currentMouseLocation: CGPoint,
        minimumSize: CGSize = CGSize(width: 1, height: 1),
        maximumSize: CGSize? = nil
    ) -> CGRect {
        let minimumWidth = max(1, minimumSize.width)
        let minimumHeight = max(1, minimumSize.height)
        let requestedWidth = initialFrame.width + currentMouseLocation.x - startMouseLocation.x
        let requestedHeight = initialFrame.height + currentMouseLocation.y - startMouseLocation.y

        let maximumWidth = max(maximumSize?.width ?? .greatestFiniteMagnitude, minimumWidth)
        let maximumHeight = max(maximumSize?.height ?? .greatestFiniteMagnitude, minimumHeight)

        return CGRect(
            origin: initialFrame.origin,
            size: CGSize(
                width: min(max(requestedWidth, minimumWidth), maximumWidth),
                height: min(max(requestedHeight, minimumHeight), maximumHeight)
            )
        )
    }
}
