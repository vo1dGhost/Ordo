import ApplicationServices
import Foundation

/// 仅激活已确认的前窗；不得回退到会带起同 App 其他窗口的普通激活接口。
protocol SingleWindowProcessActivating: Sendable {
    func activateFrontWindow(pid: pid_t) -> OSStatus
}

struct SingleWindowProcessActivator: SingleWindowProcessActivating {
    static let options = OrdoSingleWindowActivationOptions

    func activateFrontWindow(pid: pid_t) -> OSStatus {
        OrdoActivateFrontWindowForPID(pid)
    }
}

enum AXWindowFocusCompatibility {
    static func isSoftFailure(_ result: AXError) -> Bool {
        switch result {
        case .attributeUnsupported, .noValue, .notImplemented, .cannotComplete, .actionUnsupported:
            return true
        default:
            return false
        }
    }
}

enum SingleWindowFocusIdentity: Equatable, Sendable {
    case main
    case focused
}

/// 最终身份门控不让出执行器，防止混用两轮窗口状态后激活另一个前窗。
enum SingleWindowFocusTargetGate {
    static func confirm<Owner: Actor>(
        on owner: isolated Owner,
        validate: (isolated Owner) throws -> Void,
        matches: (isolated Owner, SingleWindowFocusIdentity) throws -> Bool
    ) throws -> Bool {
        for identity in [SingleWindowFocusIdentity.main, .focused, .main] {
            try Task.checkCancellation()
            try validate(owner)
            try Task.checkCancellation()
            guard try matches(owner, identity) else { return false }
            try Task.checkCancellation()
        }
        return true
    }

    static func activateIfConfirmed<Owner: Actor>(
        on owner: isolated Owner,
        validate: (isolated Owner) throws -> Void,
        matches: (isolated Owner, SingleWindowFocusIdentity) throws -> Bool,
        activate: (isolated Owner) -> OSStatus
    ) throws -> Bool {
        guard try confirm(on: owner, validate: validate, matches: matches) else { return false }
        try validate(owner)
        try Task.checkCancellation()
        return activate(owner) == noErr
    }
}

enum SingleWindowFocusStep: CaseIterable, Sendable {
    case raise
    case prepareMain
    case prepareFocus
    case confirmTarget
    case activate
    case confirmFocus
}

/// 将副作用的先后和取消边界与 AX 引用分离，使安全门控可在无辅助功能权限时测试。
enum SingleWindowFocusSequence {
    static func run<Owner: Actor>(
        on owner: isolated Owner,
        perform: (isolated Owner, SingleWindowFocusStep) async throws -> Bool
    ) async throws -> Bool {
        for step in SingleWindowFocusStep.allCases {
            try Task.checkCancellation()
            let shouldContinue = try await perform(owner, step)
            // 同步 AX 会阻塞主执行器；先交付已排队的松键/撤权事件，再允许下一步副作用。
            await Task.yield()
            try Task.checkCancellation()
            guard shouldContinue else { return false }
        }
        return true
    }
}
