import CoreGraphics
import Foundation
import os

/// 输入接收独占一个 RunLoop，不与主线程上的同步 AX 调用竞争。
/// CF 引用不对外传递；共享状态完全受锁保护，Tap 的安装、重启和销毁均在输入线程执行。
final class InputEventThread: Sendable {
    private struct State {
        var runLoop: CFRunLoop?
        var tap: CFMachPort?
        var source: CFRunLoopSource?
        let relay: InputEventRelay
        var installationError: EventSourceError?

        mutating func removeTap() {
            if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
            if let source { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
            if let tap { CFMachPortInvalidate(tap) }
            source = nil
            tap = nil
        }
    }

    // CoreFoundation 未声明 Sendable；引用仅在锁内访问，绝不从临界区返回。
    private let state: OSAllocatedUnfairLock<State>

    init(relay: InputEventRelay) {
        let state = OSAllocatedUnfairLock(uncheckedState: State(relay: relay))
        self.state = state
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread {
            autoreleasepool {
                let runLoop = CFRunLoopGetCurrent()
                var context = CFRunLoopSourceContext()
                let keepAlive = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context)
                CFRunLoopAddSource(runLoop, keepAlive, .commonModes)
                state.withLockUnchecked { $0.runLoop = runLoop }
                ready.signal()
                CFRunLoopRun()
                CFRunLoopRemoveSource(runLoop, keepAlive, .commonModes)
            }
        }
        thread.name = "com.ghoooooost.Ordo.InputEventTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
    }

    deinit {
        let state = state
        state.withLockUnchecked { current in
            guard let runLoop = current.runLoop else { return }
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
                state.withLockUnchecked {
                    $0.removeTap()
                    $0.runLoop = nil
                }
                CFRunLoopStop(CFRunLoopGetCurrent())
            }
            CFRunLoopWakeUp(runLoop)
        }
    }

    var isEnabled: Bool {
        state.withLockUnchecked { $0.tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }
    }

    @MainActor func install() throws {
        performAndWait { [state] in
            state.withLockUnchecked { current in
                current.removeTap()
                current.installationError = nil
                let mask = (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
                    | (CGEventMask(1) << CGEventType.mouseMoved.rawValue)
                guard let tap = CGEvent.tapCreate(
                    tap: .cgSessionEventTap,
                    place: .headInsertEventTap,
                    options: .listenOnly,
                    eventsOfInterest: mask,
                    callback: ordoEventTapCallback,
                    userInfo: Unmanaged.passUnretained(current.relay).toOpaque()
                ) else {
                    current.installationError = .eventTapCreationFailed
                    return
                }
                guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
                    CFMachPortInvalidate(tap)
                    current.installationError = .runLoopSourceCreationFailed
                    return
                }
                current.tap = tap
                current.source = source
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        if let error = state.withLockUnchecked({ $0.installationError }) { throw error }
    }

    @MainActor func reenableIfValid() -> Bool {
        performAndWait { [state] in
            state.withLockUnchecked { current in
                if let tap = current.tap, CFMachPortIsValid(tap) {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
        }
        return isEnabled
    }

    @MainActor func stop() {
        // 等待输入线程上的旧回调结束后才返回，保证重启不能复用尚在回调中的旧 refcon。
        performAndWait { [state] in state.withLockUnchecked { $0.removeTap() } }
    }

    func perform(_ action: @escaping @Sendable () -> Void) {
        state.withLockUnchecked { current in
            guard let runLoop = current.runLoop else { return }
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue, action)
            CFRunLoopWakeUp(runLoop)
        }
    }

    private func performAndWait(_ action: @escaping @Sendable () -> Void) {
        let finished = DispatchSemaphore(value: 0)
        perform {
            action()
            finished.signal()
        }
        finished.wait()
    }
}
