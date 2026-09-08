import CoreGraphics
import Darwin
import Foundation

enum InteractionMode: String, CaseIterable, Codable, Sendable {
    case resize
    case snap
    case move
}

/// 一次窗口手势最终成功写入后的结果；不包含窗口身份或几何信息。
enum GestureOutcome: Equatable, Sendable {
    case moved
    case resized
    case snapped(SnapLayout)
}

/// 八向径向手势对应的布局，顺序按屏幕上的顺时针方向排列。
enum SnapLayout: String, CaseIterable, Codable, Sendable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left
}

/// 捕获手势起点时的窗口快照。`id` 只在当前控制器生命周期内有效。
struct WindowSnapshot: Sendable, Equatable {
    let id: UUID
    var frame: CGRect
    let pid: pid_t

    init(id: UUID, frame: CGRect, pid: pid_t) {
        self.id = id
        self.frame = frame
        self.pid = pid
    }
}

enum GestureSessionPhase: Sendable, Equatable {
    case tracking
    case active
    case ended
}

/// 一次按键手势的纯状态模型。窗口和排布屏幕在初始化后不会更换。
struct GestureSession: Sendable, Equatable {
    static let defaultActivationThreshold: CGFloat = 4

    let mode: InteractionMode
    let window: WindowSnapshot
    let startMouseLocation: CGPoint
    let lockedVisibleFrame: CGRect?
    let activationThreshold: CGFloat

    private(set) var latestMouseLocation: CGPoint
    private(set) var phase: GestureSessionPhase = .tracking
    private(set) var selectedLayout: SnapLayout?

    init(
        mode: InteractionMode,
        window: WindowSnapshot,
        startMouseLocation: CGPoint,
        lockedVisibleFrame: CGRect? = nil,
        activationThreshold: CGFloat = GestureSession.defaultActivationThreshold
    ) {
        self.mode = mode
        self.window = window
        self.startMouseLocation = startMouseLocation
        self.latestMouseLocation = startMouseLocation
        self.lockedVisibleFrame = lockedVisibleFrame
        self.activationThreshold = max(0, activationThreshold)
    }

    var displacement: CGVector {
        CGVector(
            dx: latestMouseLocation.x - startMouseLocation.x,
            dy: latestMouseLocation.y - startMouseLocation.y
        )
    }

    var distanceFromStart: CGFloat {
        hypot(displacement.dx, displacement.dy)
    }

    var isEnded: Bool {
        phase == .ended
    }

    /// 更新指针位置，并返回本次更新是否刚刚越过启动阈值。
    @discardableResult
    mutating func updateMouseLocation(_ location: CGPoint) -> Bool {
        guard phase != .ended else {
            return false
        }

        latestMouseLocation = location
        guard phase == .tracking, distanceFromStart > activationThreshold else {
            return false
        }

        phase = .active
        return true
    }

    mutating func setSelectedLayout(_ layout: SnapLayout?) {
        guard phase != .ended, mode == .snap else {
            return
        }
        selectedLayout = layout
    }

    /// 正常松键结束。返回值仅供排布模式在松键时提交。
    @discardableResult
    mutating func end() -> SnapLayout? {
        guard phase != .ended else {
            return nil
        }
        let committedLayout = mode == .snap ? selectedLayout : nil
        phase = .ended
        selectedLayout = nil
        return committedLayout
    }

    /// 权限撤销、屏幕变化等异常路径不应提交排布。
    mutating func cancel() {
        phase = .ended
        selectedLayout = nil
    }
}
