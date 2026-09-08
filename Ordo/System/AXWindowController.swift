import ApplicationServices
import CoreGraphics
import Foundation

struct WindowFrameMismatch: OptionSet, Equatable, Sendable {
    let rawValue: UInt8

    static let position = WindowFrameMismatch(rawValue: 1 << 0)
    static let size = WindowFrameMismatch(rawValue: 1 << 1)
}

/// 系统辅助功能调用的可恢复错误。调用方应把错误转成简短状态，而不是终止应用。
enum AXWindowControllerError: Error, Equatable, LocalizedError, Sendable {
    case accessibilityPermissionRequired
    case noWindowAtPoint
    case nativeFullScreenWindow
    case attributeNotWritable(String)
    case invalidAttributeValue(String)
    case targetFrameRejected(WindowFrameMismatch)
    case windowNoLongerAvailable(UUID)
    case operationTimedOut(String)
    case operationFailed(String, code: Int32)

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "需要辅助功能权限"
        case .noWindowAtPoint:
            return "鼠标下没有可管理的窗口"
        case .nativeFullScreenWindow:
            return "原生全屏窗口暂不支持管理"
        case let .attributeNotWritable(attribute):
            return "窗口属性不可修改：\(attribute)"
        case let .invalidAttributeValue(attribute):
            return "窗口返回了无效属性：\(attribute)"
        case let .targetFrameRejected(mismatch):
            switch mismatch {
            case .position:
                return "目标应用未接受排布位置"
            case .size:
                return "目标应用未接受排布尺寸"
            default:
                return "目标应用未接受排布位置或尺寸"
            }
        case .windowNoLongerAvailable:
            return "目标窗口已关闭或不可用"
        case let .operationTimedOut(operation):
            return "窗口操作超时：\(operation)"
        case let .operationFailed(operation, code):
            return "窗口操作失败：\(operation)（AX \(code)）"
        }
    }
}

/// 将系统窗口控制与手势状态机隔离，测试可用纯内存实现替代。
protocol WindowControlling: Sendable {
    func captureWindow(at point: CGPoint, for mode: InteractionMode) async throws -> WindowSnapshot
    func currentFrame(of window: WindowSnapshot) async throws -> CGRect

    /// 尽力置前并聚焦目标窗口，仅确认目标后激活单个前窗，不得带起同 App 其他窗口。
    func raiseWindow(_ window: WindowSnapshot) async throws

    @discardableResult
    func setPosition(_ position: CGPoint, of window: WindowSnapshot) async throws -> WindowSnapshot

    @discardableResult
    func setSize(_ size: CGSize, of window: WindowSnapshot) async throws -> WindowSnapshot

    /// 动画中间帧按“尺寸 → 位置”写入；立即或最终提交补写尺寸并验证实际 frame。
    @discardableResult
    func applyFrame(
        _ frame: CGRect,
        to window: WindowSnapshot,
        transition: WindowFrameTransition
    ) async throws -> WindowSnapshot

    func release(_ window: WindowSnapshot) async
    func accessibilityPermissionDidRecover() async
    func releaseAll() async
}

extension WindowControlling {
    func accessibilityPermissionDidRecover() async {}
}

/// 排布动画按阶段使用不同的 AX 属性写入序列。
enum WindowFrameWriteStep: Equatable, Sendable {
    case size
    case position
}

enum WindowFrameWritePlan: Equatable, Sendable {
    case intermediate
    case exact

    var steps: [WindowFrameWriteStep] {
        switch self {
        case .intermediate:
            return [.size, .position]
        case .exact:
            return [.size, .position, .size]
        }
    }
}

enum AXWindowRaiseCompatibility {
    /// Raise 只是单窗口前置提示；目标不支持或调用超时时仍保留几何操作，且不重试。
    static func shouldContinue(after result: AXError) -> Bool {
        switch result {
        // SwiftUI 自身窗口的 AXRaise 也可能返回 attributeUnsupported，仍应保留几何操作。
        case .success, .attributeUnsupported, .actionUnsupported, .notImplemented, .cannotComplete:
            return true
        default:
            return false
        }
    }
}

struct AXEnhancedUserInterfaceSuppressionLease: Hashable, Sendable {
    let pid: pid_t
    let ownerID: UUID
}

enum AXEnhancedUserInterfaceCompatibility {
    static func strictBooleanValue(
        readResult: AXError,
        value: CFTypeRef?
    ) -> Bool? {
        guard readResult == .success,
              let value,
              CFGetTypeID(value) == CFBooleanGetTypeID()
        else {
            return nil
        }
        return (value as? NSNumber)?.boolValue
    }

    static func isStrictlyEnabled(
        readResult: AXError,
        value: CFTypeRef?
    ) -> Bool {
        strictBooleanValue(readResult: readResult, value: value) == true
    }

    static func shouldRetryRestoration(after result: AXError) -> Bool {
        switch result {
        case .cannotComplete, .apiDisabled, .failure:
            return true
        default:
            return false
        }
    }
}

/// 跟踪同一目标应用内可能重叠的排布操作；空 owner 集合表示等待恢复原值。
struct AXEnhancedUserInterfaceSuppressionRegistry: Sendable {
    private var ownersByPID: [pid_t: Set<UUID>] = [:]

    func isTracking(pid: pid_t) -> Bool {
        ownersByPID[pid] != nil
    }

    func isAwaitingRestoration(pid: pid_t) -> Bool {
        ownersByPID[pid]?.isEmpty == true
    }

    func hasActiveOwners(pid: pid_t) -> Bool {
        guard let owners = ownersByPID[pid] else { return false }
        return !owners.isEmpty
    }

    var trackedPIDs: [pid_t] {
        Array(ownersByPID.keys)
    }

    mutating func addOwner(
        pid: pid_t,
        ownerID: UUID
    ) -> AXEnhancedUserInterfaceSuppressionLease {
        ownersByPID[pid, default: []].insert(ownerID)
        return AXEnhancedUserInterfaceSuppressionLease(pid: pid, ownerID: ownerID)
    }

    mutating func markAwaitingRestoration(pid: pid_t) {
        guard ownersByPID[pid] == nil else { return }
        ownersByPID[pid] = []
    }

    /// 返回 `true` 表示最后一个 owner 已离开，应尝试恢复目标应用的原始值。
    mutating func removeOwner(_ lease: AXEnhancedUserInterfaceSuppressionLease) -> Bool {
        guard var owners = ownersByPID[lease.pid], owners.remove(lease.ownerID) != nil else {
            return false
        }
        ownersByPID[lease.pid] = owners
        return owners.isEmpty
    }

    mutating func finishRestoration(pid: pid_t) {
        guard ownersByPID[pid]?.isEmpty == true else { return }
        ownersByPID.removeValue(forKey: pid)
    }

    mutating func removeAll() {
        ownersByPID.removeAll(keepingCapacity: true)
    }
}

enum WindowFrameVerificationPolicy {
    static let tolerance: CGFloat = 2
    static let maximumReadAttempts = 2
    static let retryDelay: Duration = .milliseconds(17)

    static func matches(_ actual: CGRect, _ target: CGRect) -> Bool {
        mismatch(actual, target).isEmpty
    }

    static func mismatch(_ actual: CGRect, _ target: CGRect) -> WindowFrameMismatch {
        var result: WindowFrameMismatch = []
        if abs(actual.minX - target.minX) > tolerance
            || abs(actual.minY - target.minY) > tolerance {
            result.insert(.position)
        }
        if abs(actual.width - target.width) > tolerance
            || abs(actual.height - target.height) > tolerance {
            result.insert(.size)
        }
        return result
    }
}

/// 所有 AXUIElement 都只保存在 actor 内，避免跨线程共享不可 Sendable 的 CF 对象。
actor AXWindowController: WindowControlling {
    /// 同进程 AX 会同步重入 Ordo 的 AppKit/SwiftUI；统一绑定主执行器可保证
    /// 命中测试、单窗口置前和 frame 写入都满足 AppKit 的线程约束，同时 AX 引用仍只在本 actor 内。
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        MainActor.sharedUnownedExecutor
    }

    private struct TrackedWindow {
        let element: AXUIElement
        let application: AXUIElement
        let pid: pid_t
    }

    private static var fullScreenAttribute: CFString { "AXFullScreen" as CFString }
    // Finder 等应用开启此未公开 AX 属性后会自行平滑处理位置和尺寸写入。
    // 仅在排布操作期间对原值为 true 的目标临时关闭，并在所有退出路径恢复。
    private static var enhancedUserInterfaceAttribute: CFString {
        "AXEnhancedUserInterface" as CFString
    }
    private static let messagingTimeout: Float = 0.35

    private var trackedWindows: [UUID: TrackedWindow] = [:]
    private var enhancedUserInterfaceRegistry = AXEnhancedUserInterfaceSuppressionRegistry()
    private var enhancedUserInterfaceApplications: [pid_t: AXUIElement] = [:]
    private let processActivator: any SingleWindowProcessActivating

    init(processActivator: any SingleWindowProcessActivating = SingleWindowProcessActivator()) {
        self.processActivator = processActivator
    }

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

    func raiseWindow(_ window: WindowSnapshot) async throws {
        _ = try await SingleWindowFocusSequence.run(on: self) { controller, step in
            try await controller.performFocusStep(step, for: window)
        }
    }

    private func performFocusStep(
        _ step: SingleWindowFocusStep,
        for window: WindowSnapshot
    ) async throws -> Bool {
        do {
            try Task.checkCancellation()
            let tracked = try validatedWindow(for: window)
            try Task.checkCancellation()

            switch step {
            case .raise:
                let result = AXUIElementPerformAction(tracked.element, kAXRaiseAction as CFString)
                guard AXWindowRaiseCompatibility.shouldContinue(after: result) else {
                    throw mappedError(result, operation: "置前目标窗口", windowID: window.id)
                }
                // 超时可能已产生部分副作用，不能据此激活进程，也不能重试。
                return result == .success
            case .prepareMain:
                return try await prepareFocusAttribute(kAXMainAttribute as CFString, for: window)
            case .prepareFocus:
                return try await prepareFocusAttribute(kAXFocusedAttribute as CFString, for: window)
            case .confirmTarget:
                return try targetOwnsMainAndFocusedWindow(window)
            case .activate:
                // 上一阶段曾让出执行器，用户可能已切换同 App 的主窗；激活前再核对一次。
                return try SingleWindowFocusTargetGate.activateIfConfirmed(
                    on: self,
                    validate: { controller in try controller.validateFocusTarget(window) },
                    matches: { controller, identity in
                        try controller.focusIdentityMatchesTarget(identity, window: window)
                    },
                    activate: { controller in
                        controller.processActivator.activateFrontWindow(pid: window.pid)
                    }
                )
            case .confirmFocus:
                guard try targetOwnsMainAndFocusedWindow(window) else { return false }
                try validateFocusTarget(window)
                var value: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(
                    tracked.application,
                    kAXFrontmostAttribute as CFString,
                    &value
                )
                guard try focusOperationSucceeded(result, operation: "核对目标应用焦点", window: window) else {
                    return false
                }
                // API 成功不等于焦点转移成功；同时核对前台应用与目标窗口身份。
                return AXEnhancedUserInterfaceCompatibility.strictBooleanValue(
                    readResult: result,
                    value: value
                ) == true
            }
        } catch AXWindowControllerError.operationTimedOut {
            // 焦点准备不可确认时保持几何操作可用；权限或窗口失效仍向调用方抛出。
            return false
        }
    }

    private func prepareFocusAttribute(
        _ attribute: CFString,
        for window: WindowSnapshot
    ) async throws -> Bool {
        let tracked = try validatedWindow(for: window)
        var isSettable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(tracked.element, attribute, &isSettable)
        // 不可写并不代表目标不是主窗口；后续必须用 application 的窗口身份确认。
        if result == .attributeUnsupported { return true }
        guard try focusOperationSucceeded(result, operation: "检查窗口焦点属性", window: window) else {
            return false
        }
        guard isSettable.boolValue else { return true }

        let current = try await focusCheckpoint(for: window)
        let writeResult = AXUIElementSetAttributeValue(current.element, attribute, kCFBooleanTrue)
        return try focusOperationSucceeded(writeResult, operation: "准备目标窗口焦点", window: window)
    }

    private func targetOwnsMainAndFocusedWindow(_ window: WindowSnapshot) throws -> Bool {
        try SingleWindowFocusTargetGate.confirm(
            on: self,
            validate: { controller in try controller.validateFocusTarget(window) },
            matches: { controller, identity in
                try controller.focusIdentityMatchesTarget(identity, window: window)
            }
        )
    }

    private func validateFocusTarget(_ window: WindowSnapshot) throws {
        try Task.checkCancellation()
        _ = try validatedWindow(for: window)
        try Task.checkCancellation()
    }

    private func focusIdentityMatchesTarget(
        _ identity: SingleWindowFocusIdentity,
        window: WindowSnapshot
    ) throws -> Bool {
        guard let tracked = trackedWindows[window.id], tracked.pid == window.pid else {
            throw AXWindowControllerError.windowNoLongerAvailable(window.id)
        }
        let attribute = identity == .main ? kAXMainWindowAttribute : kAXFocusedWindowAttribute
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(tracked.application, attribute as CFString, &value)
        guard try focusOperationSucceeded(result, operation: "核对目标窗口身份", window: window),
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return false }
        return CFEqual(value, tracked.element)
    }

    private func focusCheckpoint(for window: WindowSnapshot) async throws -> TrackedWindow {
        await Task.yield()
        try Task.checkCancellation()
        let tracked = try validatedWindow(for: window)
        try Task.checkCancellation()
        return tracked
    }

    private func focusOperationSucceeded(
        _ result: AXError,
        operation: String,
        window: WindowSnapshot
    ) throws -> Bool {
        if result == .success { return true }
        if AXWindowFocusCompatibility.isSoftFailure(result) { return false }
        throw mappedError(result, operation: operation, windowID: window.id)
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
    func applyFrame(
        _ frame: CGRect,
        to window: WindowSnapshot,
        transition: WindowFrameTransition
    ) async throws -> WindowSnapshot {
        try Task.checkCancellation()
        let tracked = try validatedWindow(for: window)
        let suppressionLease = acquireEnhancedUserInterfaceSuppression(for: tracked)
        defer {
            if let suppressionLease {
                releaseEnhancedUserInterfaceSuppression(suppressionLease)
            }
        }
        try Task.checkCancellation()

        switch transition {
        case .immediate:
            return try await applyFrameImmediately(frame, to: window)
        case let .animated(animation):
            return try await animateFrame(frame, to: window, animation: animation)
        }
    }

    private func animateFrame(
        _ frame: CGRect,
        to window: WindowSnapshot,
        animation: WindowFrameAnimation
    ) async throws -> WindowSnapshot {
        try Task.checkCancellation()
        let tracked = try validatedWindow(for: window)
        let target = frame.standardized
        guard target.width > 0, target.height > 0 else {
            throw AXWindowControllerError.invalidAttributeValue(kAXSizeAttribute as String)
        }
        let initial = try readFrame(from: tracked.element)
        let durationSeconds = Self.seconds(in: animation.duration)

        guard durationSeconds > 0,
              animation.frameInterval > .zero,
              !WindowFrameVerificationPolicy.matches(initial, target)
        else {
            return try await applyFrameImmediately(target, to: window)
        }

        let clock = ContinuousClock()
        let start = clock.now
        let end = start.advanced(by: animation.duration)
        var elapsed = start.duration(to: clock.now)

        while let deadline = animation.nextSampleDeadline(after: elapsed) {
            try Task.checkCancellation()
            guard trackedWindows[window.id]?.pid == window.pid else {
                throw AXWindowControllerError.windowNoLongerAvailable(window.id)
            }

            try await clock.sleep(
                until: start.advanced(by: deadline),
                tolerance: .milliseconds(1)
            )
            try Task.checkCancellation()
            guard trackedWindows[window.id]?.pid == window.pid else {
                throw AXWindowControllerError.windowNoLongerAvailable(window.id)
            }

            elapsed = start.duration(to: clock.now)
            let progress = Self.seconds(in: elapsed) / durationSeconds
            guard progress < 1 else { break }

            let intermediate = animation.interpolatedFrame(
                from: initial,
                to: target,
                progress: progress
            )
            try writeFrame(intermediate, to: tracked.element, plan: .intermediate)
            elapsed = start.duration(to: clock.now)
        }

        let afterIntermediateFrames = clock.now
        if afterIntermediateFrames < end {
            try await clock.sleep(until: end, tolerance: .milliseconds(1))
        }

        try Task.checkCancellation()
        return try await applyFrameImmediately(target, to: window)
    }

    private func applyFrameImmediately(
        _ frame: CGRect,
        to window: WindowSnapshot
    ) async throws -> WindowSnapshot {
        try Task.checkCancellation()
        let tracked = try validatedWindow(for: window)
        let target = frame.standardized
        guard target.width > 0, target.height > 0 else {
            throw AXWindowControllerError.invalidAttributeValue(kAXSizeAttribute as String)
        }

        // 部分应用会在改尺寸时同步调整位置，因此位置写入后再补写一次尺寸。
        try writeFrame(target, to: tracked.element, plan: .exact)

        let clock = ContinuousClock()
        var lastActualFrame: CGRect?
        for attempt in 0..<WindowFrameVerificationPolicy.maximumReadAttempts {
            try Task.checkCancellation()
            guard trackedWindows[window.id]?.pid == window.pid else {
                throw AXWindowControllerError.windowNoLongerAvailable(window.id)
            }
            let actual = try refreshedSnapshot(window, element: tracked.element)
            lastActualFrame = actual.frame
            if WindowFrameVerificationPolicy.matches(actual.frame, target) {
                return actual
            }

            guard attempt + 1 < WindowFrameVerificationPolicy.maximumReadAttempts else {
                break
            }
            try await clock.sleep(
                for: WindowFrameVerificationPolicy.retryDelay,
                tolerance: .milliseconds(1)
            )
        }

        throw AXWindowControllerError.targetFrameRejected(
            lastActualFrame.map {
                WindowFrameVerificationPolicy.mismatch($0, target)
            } ?? [.position, .size]
        )
    }

    func release(_ window: WindowSnapshot) async {
        trackedWindows.removeValue(forKey: window.id)
        retryPendingEnhancedUserInterfaceRestoration(pid: window.pid)
    }

    func accessibilityPermissionDidRecover() async {
        for pid in enhancedUserInterfaceRegistry.trackedPIDs
            where enhancedUserInterfaceRegistry.isAwaitingRestoration(pid: pid) {
            restoreEnhancedUserInterfaceApplication(pid: pid)
        }
    }

    func releaseAll() async {
        restoreAllEnhancedUserInterfaceApplications()
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

    private func writeFrame(
        _ frame: CGRect,
        to element: AXUIElement,
        plan: WindowFrameWritePlan
    ) throws {
        for step in plan.steps {
            try Task.checkCancellation()
            switch step {
            case .size:
                try writeSize(
                    frame.size,
                    attribute: kAXSizeAttribute as CFString,
                    to: element
                )
            case .position:
                try writePoint(
                    frame.origin,
                    attribute: kAXPositionAttribute as CFString,
                    to: element
                )
            }
        }
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

    private static func seconds(in duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    // MARK: - Finder 与慢速 AX 应用兼容

    private func acquireEnhancedUserInterfaceSuppression(
        for tracked: TrackedWindow
    ) -> AXEnhancedUserInterfaceSuppressionLease? {
        if enhancedUserInterfaceRegistry.hasActiveOwners(pid: tracked.pid) {
            return enhancedUserInterfaceRegistry.addOwner(
                pid: tracked.pid,
                ownerID: UUID()
            )
        }

        var value: CFTypeRef?
        let readResult = AXUIElementCopyAttributeValue(
            tracked.application,
            Self.enhancedUserInterfaceAttribute,
            &value
        )
        guard let isEnabled = AXEnhancedUserInterfaceCompatibility.strictBooleanValue(
            readResult: readResult,
            value: value
        ) else {
            if enhancedUserInterfaceRegistry.isAwaitingRestoration(pid: tracked.pid),
               !AXEnhancedUserInterfaceCompatibility.shouldRetryRestoration(after: readResult) {
                enhancedUserInterfaceRegistry.finishRestoration(pid: tracked.pid)
                enhancedUserInterfaceApplications.removeValue(forKey: tracked.pid)
            }
            return nil
        }

        if enhancedUserInterfaceRegistry.isAwaitingRestoration(pid: tracked.pid), isEnabled {
            enhancedUserInterfaceRegistry.finishRestoration(pid: tracked.pid)
            enhancedUserInterfaceApplications.removeValue(forKey: tracked.pid)
        }

        if isEnabled {
            let disableResult = AXUIElementSetAttributeValue(
                tracked.application,
                Self.enhancedUserInterfaceAttribute,
                kCFBooleanFalse
            )
            guard disableResult == .success else {
                if AXEnhancedUserInterfaceCompatibility.shouldRetryRestoration(
                    after: disableResult
                ) {
                    enhancedUserInterfaceApplications[tracked.pid] = tracked.application
                    enhancedUserInterfaceRegistry.markAwaitingRestoration(pid: tracked.pid)
                }
                return nil
            }
        } else if !enhancedUserInterfaceRegistry.isAwaitingRestoration(pid: tracked.pid) {
            return nil
        }

        enhancedUserInterfaceApplications[tracked.pid] = tracked.application
        return enhancedUserInterfaceRegistry.addOwner(
            pid: tracked.pid,
            ownerID: UUID()
        )
    }

    private func releaseEnhancedUserInterfaceSuppression(
        _ lease: AXEnhancedUserInterfaceSuppressionLease
    ) {
        guard enhancedUserInterfaceRegistry.removeOwner(lease) else { return }
        restoreEnhancedUserInterfaceApplication(pid: lease.pid)
    }

    private func retryPendingEnhancedUserInterfaceRestoration(pid: pid_t) {
        guard enhancedUserInterfaceRegistry.isAwaitingRestoration(pid: pid) else { return }
        restoreEnhancedUserInterfaceApplication(pid: pid)
    }

    private func restoreEnhancedUserInterfaceApplication(pid: pid_t) {
        guard let application = enhancedUserInterfaceApplications[pid] else {
            enhancedUserInterfaceRegistry.finishRestoration(pid: pid)
            return
        }

        let result = AXUIElementSetAttributeValue(
            application,
            Self.enhancedUserInterfaceAttribute,
            kCFBooleanTrue
        )
        if AXEnhancedUserInterfaceCompatibility.shouldRetryRestoration(after: result) {
            // 超时或权限暂时不可用时保留原引用，在对应窗口释放时再尝试一次。
            return
        }
        enhancedUserInterfaceRegistry.finishRestoration(pid: pid)
        enhancedUserInterfaceApplications.removeValue(forKey: pid)
    }

    private func restoreAllEnhancedUserInterfaceApplications() {
        for pid in enhancedUserInterfaceRegistry.trackedPIDs {
            if let application = enhancedUserInterfaceApplications[pid] {
                _ = AXUIElementSetAttributeValue(
                    application,
                    Self.enhancedUserInterfaceAttribute,
                    kCFBooleanTrue
                )
            }
        }
        enhancedUserInterfaceRegistry.removeAll()
        enhancedUserInterfaceApplications.removeAll(keepingCapacity: true)
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
