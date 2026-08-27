import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// 系统辅助功能调用的可恢复错误。调用方应把错误转成简短状态，而不是终止应用。
enum AXWindowControllerError: Error, Equatable, LocalizedError, Sendable {
    case accessibilityPermissionRequired
    case noWindowAtPoint
    case ownProcessWindow
    case nativeFullScreenWindow
    case attributeNotWritable(String)
    case invalidAttributeValue(String)
    case targetFrameRejected
    case windowNoLongerAvailable(UUID)
    case operationTimedOut(String)
    case operationFailed(String, code: Int32)
    case activationFailed(pid_t)

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "需要辅助功能权限"
        case .noWindowAtPoint:
            return "鼠标下没有可管理的窗口"
        case .ownProcessWindow:
            return "不能管理 Ordo 自己的窗口"
        case .nativeFullScreenWindow:
            return "原生全屏窗口暂不支持管理"
        case let .attributeNotWritable(attribute):
            return "窗口属性不可修改：\(attribute)"
        case let .invalidAttributeValue(attribute):
            return "窗口返回了无效属性：\(attribute)"
        case .targetFrameRejected:
            return "目标应用未接受该排布尺寸"
        case .windowNoLongerAvailable:
            return "目标窗口已关闭或不可用"
        case let .operationTimedOut(operation):
            return "窗口操作超时：\(operation)"
        case let .operationFailed(operation, code):
            return "窗口操作失败：\(operation)（AX \(code)）"
        case let .activationFailed(pid):
            return "无法激活目标应用（PID \(pid)）"
        }
    }
}

/// 将系统窗口控制与手势状态机隔离，测试可用纯内存实现替代。
protocol WindowControlling: Sendable {
    func captureWindow(at point: CGPoint, for mode: InteractionMode) async throws -> WindowSnapshot
    func currentFrame(of window: WindowSnapshot) async throws -> CGRect

    @discardableResult
    func setPosition(_ position: CGPoint, of window: WindowSnapshot) async throws -> WindowSnapshot

    @discardableResult
    func setSize(_ size: CGSize, of window: WindowSnapshot) async throws -> WindowSnapshot

    /// 自动排布必须按“尺寸 → 位置 → 尺寸”写入，并返回目标应用实际接受的 frame。
    @discardableResult
    func applyFrame(_ frame: CGRect, to window: WindowSnapshot) async throws -> WindowSnapshot

    func activateAndRaise(_ window: WindowSnapshot) async throws
    func release(_ window: WindowSnapshot) async
    func releaseAll() async
}

/// 所有 AXUIElement 都只保存在 actor 内，避免跨线程共享不可 Sendable 的 CF 对象。
actor AXWindowController: WindowControlling {
    private struct TrackedWindow {
        let element: AXUIElement
        let application: AXUIElement
        let pid: pid_t
    }

    private static var fullScreenAttribute: CFString { "AXFullScreen" as CFString }
    private static let messagingTimeout: Float = 0.35

    private var trackedWindows: [UUID: TrackedWindow] = [:]

    /// `prompt` 只能在用户明确点击授权入口后传入 `true`。
    nonisolated static func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        guard prompt else {
            return AXIsProcessTrusted()
        }

        // Swift 6 将 SDK 中的全局 CFString 变量视为共享可变状态；其公开常量值固定如下。
        return AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    func captureWindow(at point: CGPoint, for mode: InteractionMode) async throws -> WindowSnapshot {
        try Task.checkCancellation()
        try requirePermission()
        try Task.checkCancellation()

        let systemWideElement = AXUIElementCreateSystemWide()
        // 对 system-wide 元素设置会成为本进程后续 AX 消息的全局超时。
        _ = AXUIElementSetMessagingTimeout(systemWideElement, Self.messagingTimeout)
        var hitElement: AXUIElement?
        let hitTestResult = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(point.x),
            Float(point.y),
            &hitElement
        )

        guard hitTestResult == .success, let hitElement else {
            if hitTestResult == .noValue || hitTestResult == .attributeUnsupported {
                throw AXWindowControllerError.noWindowAtPoint
            }
            throw mappedError(hitTestResult, operation: "命中测试")
        }
        try Task.checkCancellation()

        guard let windowElement = try enclosingWindow(from: hitElement) else {
            throw AXWindowControllerError.noWindowAtPoint
        }
        _ = AXUIElementSetMessagingTimeout(windowElement, Self.messagingTimeout)

        var pid: pid_t = 0
        let pidResult = AXUIElementGetPid(windowElement, &pid)
        guard pidResult == .success else {
            throw mappedError(pidResult, operation: "读取应用标识")
        }
        guard pid != ProcessInfo.processInfo.processIdentifier else {
            throw AXWindowControllerError.ownProcessWindow
        }

        if try isNativeFullScreen(windowElement) {
            throw AXWindowControllerError.nativeFullScreenWindow
        }
        switch mode {
        case .move:
            try requireSettable(kAXPositionAttribute as CFString, on: windowElement)
        case .resize:
            try requireSettable(kAXSizeAttribute as CFString, on: windowElement)
        case .snap:
            try requireSettable(kAXPositionAttribute as CFString, on: windowElement)
            try requireSettable(kAXSizeAttribute as CFString, on: windowElement)
        }

        let application = AXUIElementCreateApplication(pid)
        _ = AXUIElementSetMessagingTimeout(application, Self.messagingTimeout)

        try Task.checkCancellation()
        let frame = try readFrame(from: windowElement)
        try Task.checkCancellation()
        let id = UUID()
        trackedWindows[id] = TrackedWindow(
            element: windowElement,
            application: application,
            pid: pid
        )
        return WindowSnapshot(id: id, frame: frame, pid: pid)
    }

    func currentFrame(of window: WindowSnapshot) async throws -> CGRect {
        try Task.checkCancellation()
        let tracked = try validatedWindow(for: window)
        try Task.checkCancellation()
        return try readFrame(from: tracked.element)
    }

    @discardableResult
    func setPosition(_ position: CGPoint, of window: WindowSnapshot) async throws -> WindowSnapshot {
        try Task.checkCancellation()
        let tracked = try validatedWindow(for: window)
        try Task.checkCancellation()
        try writePoint(position, attribute: kAXPositionAttribute as CFString, to: tracked.element)
        try Task.checkCancellation()
        return try refreshedSnapshot(window, element: tracked.element)
    }

    @discardableResult
    func setSize(_ size: CGSize, of window: WindowSnapshot) async throws -> WindowSnapshot {
        try Task.checkCancellation()
        let tracked = try validatedWindow(for: window)
        let positiveSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        try Task.checkCancellation()
        try writeSize(positiveSize, attribute: kAXSizeAttribute as CFString, to: tracked.element)
        try Task.checkCancellation()
        return try refreshedSnapshot(window, element: tracked.element)
    }

    @discardableResult
    func applyFrame(_ frame: CGRect, to window: WindowSnapshot) async throws -> WindowSnapshot {
        try Task.checkCancellation()
        let tracked = try validatedWindow(for: window)
        let target = frame.standardized
        guard target.width > 0, target.height > 0 else {
            throw AXWindowControllerError.invalidAttributeValue(kAXSizeAttribute as String)
        }

        // 部分应用会在改尺寸时同步调整位置，因此位置写入后再补写一次尺寸。
        try Task.checkCancellation()
        try writeSize(target.size, attribute: kAXSizeAttribute as CFString, to: tracked.element)
        try Task.checkCancellation()
        try writePoint(target.origin, attribute: kAXPositionAttribute as CFString, to: tracked.element)
        try Task.checkCancellation()
        try writeSize(target.size, attribute: kAXSizeAttribute as CFString, to: tracked.element)
        try Task.checkCancellation()
        let actual = try refreshedSnapshot(window, element: tracked.element)
        guard Self.framesMatch(actual.frame, target, tolerance: 2) else {
            throw AXWindowControllerError.targetFrameRejected
        }
        return actual
    }

    func activateAndRaise(_ window: WindowSnapshot) async throws {
        try Task.checkCancellation()
        let tracked = try validatedWindow(for: window)
        let pid = tracked.pid

        let activationSucceeded = try await MainActor.run {
            try Task.checkCancellation()
            return NSRunningApplication(processIdentifier: pid)?.activate(options: []) ?? false
        }
        try Task.checkCancellation()

        // AXFrontmost 是无 Apple Events 权限时的系统级后备路径。
        let frontmostResult = AXUIElementSetAttributeValue(
            tracked.application,
            kAXFrontmostAttribute as CFString,
            kCFBooleanTrue
        )
        try Task.checkCancellation()
        let raiseResult = AXUIElementPerformAction(tracked.element, kAXRaiseAction as CFString)

        guard activationSucceeded || frontmostResult == .success else {
            throw AXWindowControllerError.activationFailed(pid)
        }
        guard raiseResult == .success else {
            throw mappedError(raiseResult, operation: "置前窗口")
        }
    }

    func release(_ window: WindowSnapshot) async {
        trackedWindows.removeValue(forKey: window.id)
    }

    func releaseAll() async {
        trackedWindows.removeAll(keepingCapacity: true)
    }

    // MARK: - AX 读取与写入

    private func validatedWindow(for snapshot: WindowSnapshot) throws -> TrackedWindow {
        try requirePermission()
        guard let tracked = trackedWindows[snapshot.id], tracked.pid == snapshot.pid else {
            throw AXWindowControllerError.windowNoLongerAvailable(snapshot.id)
        }

        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(
            tracked.element,
            kAXRoleAttribute as CFString,
            &roleValue
        )
        guard roleResult == .success,
              let role = roleValue as? String,
              role == kAXWindowRole as String
        else {
            if roleResult == .success {
                throw AXWindowControllerError.windowNoLongerAvailable(snapshot.id)
            }
            throw mappedError(roleResult, operation: "验证目标窗口", windowID: snapshot.id)
        }

        if try isNativeFullScreen(tracked.element) {
            throw AXWindowControllerError.nativeFullScreenWindow
        }
        return tracked
    }

    private func enclosingWindow(from element: AXUIElement) throws -> AXUIElement? {
        var directWindowValue: CFTypeRef?
        let directWindowResult = AXUIElementCopyAttributeValue(
            element,
            kAXWindowAttribute as CFString,
            &directWindowValue
        )
        if directWindowResult == .success,
           let directWindowValue,
           CFGetTypeID(directWindowValue) == AXUIElementGetTypeID() {
            return (directWindowValue as! AXUIElement)
        }
        switch directWindowResult {
        case .success, .attributeUnsupported, .noValue:
            break
        default:
            throw mappedError(directWindowResult, operation: "读取所属窗口")
        }

        var current = element

        // 系统命中通常返回按钮、文本等子元素；向上寻找 AXWindow，限制深度防止异常树循环。
        for _ in 0..<64 {
            try Task.checkCancellation()
            var roleValue: CFTypeRef?
            let roleResult = AXUIElementCopyAttributeValue(
                current,
                kAXRoleAttribute as CFString,
                &roleValue
            )
            if roleResult == .success,
               let role = roleValue as? String,
               role == kAXWindowRole as String
            {
                return current
            }
            if roleResult != .success,
               roleResult != .attributeUnsupported,
               roleResult != .noValue {
                throw mappedError(roleResult, operation: "读取元素角色")
            }

            var parentValue: CFTypeRef?
            let parentResult = AXUIElementCopyAttributeValue(
                current,
                kAXParentAttribute as CFString,
                &parentValue
            )
            if parentResult == .attributeUnsupported || parentResult == .noValue {
                return nil
            }
            guard parentResult == .success else {
                throw mappedError(parentResult, operation: "读取元素父级")
            }
            guard let parentValue else { return nil }
            guard CFGetTypeID(parentValue) == AXUIElementGetTypeID() else {
                return nil
            }
            current = parentValue as! AXUIElement
        }

        return nil
    }

    private func isNativeFullScreen(_ element: AXUIElement) throws -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, Self.fullScreenAttribute, &value)
        switch result {
        case .success:
            return (value as? NSNumber)?.boolValue ?? false
        case .attributeUnsupported, .noValue:
            // 并非所有应用都暴露 AXFullScreen；缺失属性不应阻断普通窗口。
            return false
        default:
            throw mappedError(result, operation: "检查全屏状态")
        }
    }

    private func requireSettable(_ attribute: CFString, on element: AXUIElement) throws {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(element, attribute, &settable)
        guard result == .success else {
            throw mappedError(result, operation: "检查 \(attribute) 可写性")
        }
        guard settable.boolValue else {
            throw AXWindowControllerError.attributeNotWritable(attribute as String)
        }
    }

    private func readFrame(from element: AXUIElement) throws -> CGRect {
        try Task.checkCancellation()
        let position = try readPoint(attribute: kAXPositionAttribute as CFString, from: element)
        try Task.checkCancellation()
        let size = try readSize(attribute: kAXSizeAttribute as CFString, from: element)
        try Task.checkCancellation()
        guard size.width > 0, size.height > 0 else {
            throw AXWindowControllerError.invalidAttributeValue(kAXSizeAttribute as String)
        }
        return CGRect(origin: position, size: size)
    }

    private func readPoint(attribute: CFString, from element: AXUIElement) throws -> CGPoint {
        let value = try readAttribute(attribute, from: element)
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            throw AXWindowControllerError.invalidAttributeValue(attribute as String)
        }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgPoint else {
            throw AXWindowControllerError.invalidAttributeValue(attribute as String)
        }

        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else {
            throw AXWindowControllerError.invalidAttributeValue(attribute as String)
        }
        return point
    }

    private func readSize(attribute: CFString, from element: AXUIElement) throws -> CGSize {
        let value = try readAttribute(attribute, from: element)
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            throw AXWindowControllerError.invalidAttributeValue(attribute as String)
        }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgSize else {
            throw AXWindowControllerError.invalidAttributeValue(attribute as String)
        }

        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else {
            throw AXWindowControllerError.invalidAttributeValue(attribute as String)
        }
        return size
    }

    private func readAttribute(_ attribute: CFString, from element: AXUIElement) throws -> CFTypeRef {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else {
            throw mappedError(result, operation: "读取 \(attribute)")
        }
        return value
    }

    private func writePoint(
        _ point: CGPoint,
        attribute: CFString,
        to element: AXUIElement
    ) throws {
        var mutablePoint = point
        guard let value = AXValueCreate(.cgPoint, &mutablePoint) else {
            throw AXWindowControllerError.invalidAttributeValue(attribute as String)
        }
        try setAttribute(value, attribute: attribute, on: element)
    }

    private func writeSize(
        _ size: CGSize,
        attribute: CFString,
        to element: AXUIElement
    ) throws {
        var mutableSize = size
        guard let value = AXValueCreate(.cgSize, &mutableSize) else {
            throw AXWindowControllerError.invalidAttributeValue(attribute as String)
        }
        try setAttribute(value, attribute: attribute, on: element)
    }

    private func setAttribute(
        _ value: CFTypeRef,
        attribute: CFString,
        on element: AXUIElement
    ) throws {
        let result = AXUIElementSetAttributeValue(element, attribute, value)
        guard result == .success else {
            if result == .attributeUnsupported || result == .notImplemented {
                throw AXWindowControllerError.attributeNotWritable(attribute as String)
            }
            throw mappedError(result, operation: "写入 \(attribute)")
        }
    }

    private func refreshedSnapshot(
        _ snapshot: WindowSnapshot,
        element: AXUIElement
    ) throws -> WindowSnapshot {
        WindowSnapshot(id: snapshot.id, frame: try readFrame(from: element), pid: snapshot.pid)
    }

    private func requirePermission() throws {
        guard AXIsProcessTrusted() else {
            trackedWindows.removeAll(keepingCapacity: true)
            throw AXWindowControllerError.accessibilityPermissionRequired
        }
    }

    private static func framesMatch(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }

    private func mappedError(
        _ error: AXError,
        operation: String,
        windowID: UUID? = nil
    ) -> AXWindowControllerError {
        switch error {
        case .cannotComplete:
            return .operationTimedOut(operation)
        case .invalidUIElement:
            if let windowID {
                trackedWindows.removeValue(forKey: windowID)
                return .windowNoLongerAvailable(windowID)
            }
            return .operationFailed(operation, code: error.rawValue)
        case .apiDisabled:
            trackedWindows.removeAll(keepingCapacity: true)
            return .accessibilityPermissionRequired
        default:
            return .operationFailed(operation, code: error.rawValue)
        }
    }
}
