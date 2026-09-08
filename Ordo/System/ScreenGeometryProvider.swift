import AppKit
import CoreGraphics
import Foundation

/// 单块屏幕的不可变快照。`frame` 与 `visibleFrame` 均使用 AX/Quartz 左上原点坐标。
struct ScreenGeometry: Identifiable, Equatable, Sendable {
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let visibleFrame: CGRect
    let appKitFrame: CGRect
    let appKitVisibleFrame: CGRect
    let backingScaleFactor: CGFloat
    let mainScreenFrame: CGRect

    var id: CGDirectDisplayID { displayID }

    func appKitRect(fromAX rect: CGRect) -> CGRect {
        ScreenCoordinateConverter.quartzToAppKit(rect, mainScreenFrame: mainScreenFrame)
    }

    func appKitPoint(fromAX point: CGPoint) -> CGPoint {
        ScreenCoordinateConverter.quartzToAppKit(point, mainScreenFrame: mainScreenFrame)
    }

    func axRect(fromAppKit rect: CGRect) -> CGRect {
        ScreenCoordinateConverter.appKitToQuartz(rect, mainScreenFrame: mainScreenFrame)
    }
}

/// 屏幕枚举固定在 MainActor，因为 NSScreen 属于 AppKit UI 状态。
@MainActor
protocol ScreenGeometryProviding: AnyObject, Sendable {
    func currentScreens() -> [ScreenGeometry]
    func screen(containingAXPoint point: CGPoint) -> ScreenGeometry?
    func screenAtPointer() -> ScreenGeometry?

    /// 首次订阅会立即收到当前屏幕；之后仅在系统屏幕参数变化时发送新快照。
    func screenChanges() -> AsyncStream<[ScreenGeometry]>
}

@MainActor
final class ScreenGeometryProvider: NSObject, ScreenGeometryProviding {
    private var continuations: [UUID: AsyncStream<[ScreenGeometry]>.Continuation] = [:]

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func currentScreens() -> [ScreenGeometry] {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return []
        }

        // AppKit 的 (0, 0) 所在屏幕定义 Quartz 全局坐标的 Y 轴参考顶边。
        let mainFrame = screens.first(where: { $0.frame.origin == .zero })?.frame
            ?? NSScreen.main?.frame
            ?? screens[0].frame

        return screens.compactMap { screen in
            guard let displayID = displayID(for: screen) else {
                return nil
            }

            return ScreenGeometry(
                displayID: displayID,
                frame: ScreenCoordinateConverter.appKitToQuartz(
                    screen.frame,
                    mainScreenFrame: mainFrame
                ),
                visibleFrame: ScreenCoordinateConverter.appKitToQuartz(
                    screen.visibleFrame,
                    mainScreenFrame: mainFrame
                ),
                appKitFrame: screen.frame,
                appKitVisibleFrame: screen.visibleFrame,
                backingScaleFactor: screen.backingScaleFactor,
                mainScreenFrame: mainFrame
            )
        }
    }

    func screen(containingAXPoint point: CGPoint) -> ScreenGeometry? {
        let screens = currentScreens()
        if let containingScreen = screens.first(where: { $0.frame.contains(point) }) {
            return containingScreen
        }

        // CGRect 的最大边界不计入 contains；边界或浮点误差时选最近屏幕。
        return screens.min { squaredDistance(from: point, to: $0.frame) < squaredDistance(from: point, to: $1.frame) }
    }

    func screenAtPointer() -> ScreenGeometry? {
        guard let pointerLocation = CGEvent(source: nil)?.location else {
            return nil
        }
        return screen(containingAXPoint: pointerLocation)
    }

    func screenChanges() -> AsyncStream<[ScreenGeometry]> {
        let identifier = UUID()
        let (stream, continuation) = AsyncStream<[ScreenGeometry]>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        continuations[identifier] = continuation
        continuation.yield(currentScreens())
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.continuations.removeValue(forKey: identifier)
            }
        }
        return stream
    }

    @objc
    private func screenParametersDidChange(_ notification: Notification) {
        let snapshot = currentScreens()
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }

    private func squaredDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx: CGFloat
        if point.x < rect.minX {
            dx = rect.minX - point.x
        } else if point.x > rect.maxX {
            dx = point.x - rect.maxX
        } else {
            dx = 0
        }

        let dy: CGFloat
        if point.y < rect.minY {
            dy = rect.minY - point.y
        } else if point.y > rect.maxY {
            dy = point.y - rect.maxY
        } else {
            dy = 0
        }
        return dx * dx + dy * dy
    }
}
