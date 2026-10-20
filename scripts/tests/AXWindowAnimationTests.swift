import ApplicationServices
import Foundation
import os

// 仅由配套脚本编译，不属于 App 或 XCTest target。当前模块内的同名函数替代 AX I/O；
// 只创建本地 CF 句柄，不查询、激活或写入真实窗口，不依赖辅助功能权限。
private enum Scenario: String, CaseIterable, Sendable {
    case normal = "正常动画精确提交并恢复兼容设置"
    case immediate = "立即排布保持精确写入顺序"
    case fullScreenBeforeAnimation = "动画开始前已全屏时零写入"
    case fullScreenDuringAnimation = "首帧后进入全屏时停止几何写入"
    case permissionRevoked = "首帧后撤权时停止并在权限恢复后恢复兼容设置"
    case invalidWindow = "首帧后窗口失效时停止几何写入"
    case validationTimeout = "首帧后校验超时时停止且不重试"
    case cancelled = "首帧后取消时不补写终态"
    case slowValidation = "校验跨过动画终点时跳过过期中间帧"
}

private struct State: Sendable {
    let scenario: Scenario
    var frame = CGRect(x: 50, y: 50, width: 400, height: 300)
    var trusted = true
    var fullScreen = false
    var invalid = false
    var validationTimesOut = false
    var enhancedUserInterface = true
    var writes: [String] = []
    var unsafeGeometryAttempts = 0
    var completedFrames = 0
    var restorationAttempts = 0
    var disableCount = 0
    var failingValidations = 0
    var delayedValidation = false
    var unexpectedCalls: [String] = []
}

private enum MemoryAX {
    static let pid = pid_t.max
    static let state = OSAllocatedUnfairLock(initialState: State(scenario: .normal))
}

func AXIsProcessTrusted() -> Bool {
    MemoryAX.state.withLock { $0.trusted }
}

func AXIsProcessTrustedWithOptions(_ options: CFDictionary?) -> Bool {
    MemoryAX.state.withLock { $0.unexpectedCalls.append("授权提示") }
    return AXIsProcessTrusted()
}

func AXUIElementSetMessagingTimeout(_ element: AXUIElement, _ timeout: Float) -> AXError {
    .success
}

func AXUIElementCopyElementAtPosition(
    _ element: AXUIElement, _ x: Float, _ y: Float,
    _ result: UnsafeMutablePointer<AXUIElement?>
) -> AXError {
    result.pointee = ApplicationServices.AXUIElementCreateApplication(MemoryAX.pid)
    return .success
}

func AXUIElementGetPid(_ element: AXUIElement, _ pid: UnsafeMutablePointer<pid_t>) -> AXError {
    pid.pointee = MemoryAX.pid
    return .success
}

func AXUIElementIsAttributeSettable(
    _ element: AXUIElement, _ attribute: CFString, _ settable: UnsafeMutablePointer<DarwinBoolean>
) -> AXError {
    settable.pointee = DarwinBoolean(true)
    return .success
}

func AXUIElementPerformAction(_ element: AXUIElement, _ action: CFString) -> AXError {
    let name = action as String
    MemoryAX.state.withLock { $0.unexpectedCalls.append(name) }
    return .actionUnsupported
}

func AXUIElementCopyAttributeValue(
    _ element: AXUIElement, _ attribute: CFString, _ result: UnsafeMutablePointer<CFTypeRef?>
) -> AXError {
    let state = MemoryAX.state.withLock { $0 }
    switch attribute as String {
    case "AXWindow":
        result.pointee = ApplicationServices.AXUIElementCreateApplication(MemoryAX.pid)
    case "AXRole":
        result.pointee = "AXWindow" as CFString
    case "AXFullScreen":
        result.pointee = state.fullScreen ? kCFBooleanTrue : kCFBooleanFalse
    case "AXEnhancedUserInterface":
        result.pointee = state.enhancedUserInterface ? kCFBooleanTrue : kCFBooleanFalse
    case "AXPosition":
        var position = state.frame.origin
        result.pointee = AXValueCreate(.cgPoint, &position)
    case "AXSize":
        var size = state.frame.size
        result.pointee = AXValueCreate(.cgSize, &size)
    default:
        let name = attribute as String
        MemoryAX.state.withLock { $0.unexpectedCalls.append("读取 \(name)") }
        return .attributeUnsupported
    }
    return .success
}

func AXUIElementCopyMultipleAttributeValues(
    _ element: AXUIElement, _ attributes: CFArray, _ options: AXCopyMultipleAttributeOptions,
    _ result: UnsafeMutablePointer<CFArray?>
) -> AXError {
    let shouldDelay = MemoryAX.state.withLock { state in
        guard state.scenario == .slowValidation,
              state.completedFrames > 0, !state.delayedValidation else { return false }
        state.delayedValidation = true
        return true
    }
    // 模拟一次同步 AX 校验耗时超出剩余动画时间，不能沿用校验之前的插值进度。
    if shouldDelay { Thread.sleep(forTimeInterval: 0.22) }
    let state = MemoryAX.state.withLock { state -> State in
        if state.invalid || state.validationTimesOut { state.failingValidations += 1 }
        return state
    }
    if state.invalid { return .invalidUIElement }
    if state.validationTimesOut { return .cannotComplete }
    result.pointee = ["AXWindow", state.fullScreen] as CFArray
    return .success
}

func AXUIElementSetAttributeValue(
    _ element: AXUIElement, _ attribute: CFString, _ value: CFTypeRef
) -> AXError {
    let name = attribute as String
    if name == "AXEnhancedUserInterface" {
        let enabled = CFEqual(value, kCFBooleanTrue)
        return MemoryAX.state.withLock { state in
            if enabled { state.restorationAttempts += 1 } else { state.disableCount += 1 }
            guard state.trusted else { return .apiDisabled }
            state.enhancedUserInterface = enabled
            return .success
        }
    }
    guard name == "AXSize" || name == "AXPosition" else {
        MemoryAX.state.withLock { $0.unexpectedCalls.append("写入 \(name)") }
        return .attributeUnsupported
    }
    let isSize = name == "AXSize"
    let axValue = value as! AXValue
    var decodedSize = CGSize.zero
    var decodedPoint = CGPoint.zero
    if isSize {
        precondition(AXValueGetValue(axValue, .cgSize, &decodedSize))
    } else {
        precondition(AXValueGetValue(axValue, .cgPoint, &decodedPoint))
    }
    let size = decodedSize
    let point = decodedPoint
    let result = MemoryAX.state.withLock { state -> AXError in
        if state.fullScreen || !state.trusted || state.invalid || state.validationTimesOut {
            state.unsafeGeometryAttempts += 1
        }
        guard state.trusted else { return .apiDisabled }
        guard !state.invalid else { return .invalidUIElement }
        state.writes.append(name)
        if isSize {
            state.frame.size = size
        } else {
            state.frame.origin = point
            state.completedFrames += 1
            if state.completedFrames == 1 {
                switch state.scenario {
                case .fullScreenDuringAnimation: state.fullScreen = true
                case .permissionRevoked: state.trusted = false
                case .invalidWindow: state.invalid = true
                case .validationTimeout: state.validationTimesOut = true
                default: break
                }
            }
        }
        return .success
    }
    if !isSize, MemoryAX.state.withLock({ $0.scenario == .cancelled && $0.completedFrames == 1 }) {
        withUnsafeCurrentTask { $0?.cancel() }
    }
    return result
}

@main
private enum AXWindowAnimationTests {
    private static let target = CGRect(x: 0, y: 0, width: 1000, height: 800)

    @MainActor
    static func main() async throws {
        var failedCases = 0
        for scenario in Scenario.allCases {
            let failures = try await run(scenario)
            if failures.isEmpty {
                print("通过：\(scenario.rawValue)")
            } else {
                failedCases += 1
                print("失败：\(scenario.rawValue)：\(failures.joined(separator: "；"))")
            }
        }
        print("AX 动画隔离回归：\(Scenario.allCases.count - failedCases) 项通过，\(failedCases) 项失败。")
        if failedCases > 0 { exit(1) }
    }

    @MainActor
    private static func run(_ scenario: Scenario) async throws -> [String] {
        MemoryAX.state.withLock { $0 = State(scenario: scenario) }
        let controller = AXWindowController()
        let window = try await controller.captureWindow(at: .zero, for: .snap)
        if scenario == .fullScreenBeforeAnimation {
            MemoryAX.state.withLock { $0.fullScreen = true }
        }
        // 每个动画使用独立任务，取消用例不能影响后续场景。
        let task = Task {
            try await controller.applyFrame(
                target, to: window,
                transition: scenario == .immediate ? .immediate : .animated(.snapDefault)
            )
        }
        let result = await task.result
        await controller.release(window)
        if scenario == .permissionRevoked {
            MemoryAX.state.withLock { $0.trusted = true }
            await controller.accessibilityPermissionDidRecover()
        }
        let state = MemoryAX.state.withLock { $0 }
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message) }
        }
        check(state.unexpectedCalls.isEmpty, "出现非预期 AX 操作：\(state.unexpectedCalls)")
        check(state.unsafeGeometryAttempts == 0, "不允许操作后仍尝试写几何 \(state.unsafeGeometryAttempts) 次")
        check(state.enhancedUserInterface, "未恢复兼容设置")
        check(state.disableCount == (scenario == .fullScreenBeforeAnimation ? 0 : 1), "兼容设置准备次数不符")

        switch scenario {
        case .normal, .immediate, .slowValidation:
            if case .failure(let error) = result { failures.append("正常路径抛错：\(error)") }
            check(state.frame == target, "最终窗口 frame 不精确")
            check(Array(state.writes.suffix(3)) == ["AXSize", "AXPosition", "AXSize"], "最终写入顺序不符")
            if scenario == .immediate { check(state.writes.count == 3, "立即排布出现额外写入") }
            if scenario == .slowValidation {
                check(state.delayedValidation, "未执行慢校验")
                check(state.writes.count == 5, "慢校验后仍补写中间帧，总写入 \(state.writes.count) 次")
            }
        case .fullScreenBeforeAnimation, .fullScreenDuringAnimation:
            check(axError(result) == .nativeFullScreenWindow, "未报告原生全屏错误")
            check(state.writes.count == (scenario == .fullScreenBeforeAnimation ? 0 : 2), "全屏后继续执行动画")
        case .permissionRevoked:
            check(axError(result) == .accessibilityPermissionRequired, "未报告撤权错误")
            check(state.writes.count == 2, "撤权后继续执行动画")
            check(state.restorationAttempts >= 2, "权限恢复后未重试兼容设置恢复")
        case .invalidWindow:
            check(axError(result) == .windowNoLongerAvailable(window.id), "未在校验阶段发现窗口失效")
            check(state.writes.count == 2, "窗口失效后继续执行动画")
            check(state.failingValidations == 1, "失效校验被跳过或重试")
        case .validationTimeout:
            check(axError(result) == .operationTimedOut("验证目标窗口"), "未报告窗口校验超时")
            check(state.writes.count == 2, "校验超时后继续执行动画")
            check(state.failingValidations == 1, "超时校验被跳过或重试")
        case .cancelled:
            if case .failure(let error) = result {
                check(error is CancellationError, "取消错误类型不符")
            } else {
                failures.append("取消后仍返回成功")
            }
            check(state.writes.count == 2, "取消后补写了几何")
        }
        return failures
    }

    private static func axError(_ result: Result<WindowSnapshot, any Error>) -> AXWindowControllerError? {
        guard case .failure(let error) = result else { return nil }
        return error as? AXWindowControllerError
    }
}
