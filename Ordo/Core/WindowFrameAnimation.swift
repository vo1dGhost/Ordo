import CoreGraphics
import Foundation

/// 外部窗口 frame 过渡所需的纯动画参数与插值计算。
struct WindowFrameAnimation: Equatable, Sendable {
    let duration: Duration
    let frameInterval: Duration

    /// 八向排布的固定动画手感：200 ms，约 60 Hz。
    static let snapDefault = WindowFrameAnimation(
        duration: .milliseconds(200),
        frameInterval: .nanoseconds(16_666_667)
    )

    /// 使用 smoothstep 同时插值位置与尺寸。进度会限制在 `0...1`，不会越过端点。
    func interpolatedFrame(
        from start: CGRect,
        to end: CGRect,
        progress: Double
    ) -> CGRect {
        let clampedProgress = min(max(progress, 0), 1)
        let easedProgress = clampedProgress * clampedProgress * (3 - 2 * clampedProgress)

        return CGRect(
            x: interpolate(from: start.origin.x, to: end.origin.x, progress: easedProgress),
            y: interpolate(from: start.origin.y, to: end.origin.y, progress: easedProgress),
            width: interpolate(from: start.width, to: end.width, progress: easedProgress),
            height: interpolate(from: start.height, to: end.height, progress: easedProgress)
        )
    }

    /// 返回相对动画固定起点的下一个采样 deadline。
    ///
    /// 返回值严格晚于实际经过时间；已经错过的时间格会直接跳过。动画终点只用于最终精确写入，
    /// 因此达到或越过终点的时间格不会作为普通动画帧返回。
    func nextSampleDeadline(after elapsed: Duration) -> Duration? {
        guard duration > .zero,
              frameInterval > .zero,
              elapsed < duration
        else {
            return nil
        }

        var deadline = frameInterval
        while deadline <= elapsed {
            deadline += frameInterval
        }

        return deadline < duration ? deadline : nil
    }

    private func interpolate(from start: CGFloat, to end: CGFloat, progress: Double) -> CGFloat {
        start + (end - start) * CGFloat(progress)
    }
}

/// 窗口 frame 写入采用立即到达或逐帧动画。
enum WindowFrameTransition: Equatable, Sendable {
    case immediate
    case animated(WindowFrameAnimation)
}
