import ApplicationServices
import CoreGraphics
import Foundation

enum InputEventKind: Sendable, Equatable {
    case flagsChanged
    case mouseMoved
}

/// Event Tap 只输出手势需要的信息，不采集普通键盘内容。
struct InputEvent: Sendable, Equatable {
    let kind: InputEventKind
    let modifiers: ModifierChord
    let location: CGPoint
    let timestamp: UInt64
    let sourceEpoch: UInt64

    init(
        kind: InputEventKind,
        modifiers: ModifierChord,
        location: CGPoint,
        timestamp: UInt64,
        sourceEpoch: UInt64 = 0
    ) {
        self.kind = kind
        self.modifiers = modifiers
        self.location = location
        self.timestamp = timestamp
        self.sourceEpoch = sourceEpoch
    }
}

enum EventSourceError: Error, Equatable, LocalizedError, Sendable {
    case accessibilityPermissionRequired
    case eventTapCreationFailed
    case runLoopSourceCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "需要辅助功能权限才能监听鼠标手势"
        case .eventTapCreationFailed:
            return "无法创建系统输入监听"
        case .runLoopSourceCreationFailed:
            return "无法启动系统输入监听"
        }
    }
}

@MainActor
protocol EventSource: AnyObject, Sendable {
    var events: AsyncStream<InputEvent> { get }
    var failures: AsyncStream<EventSourceError> { get }
    var isRunning: Bool { get }
    var epoch: UInt64 { get }
    var lastError: EventSourceError? { get }

    func start() throws
    func stop()
}

/// listen-only 的 Session Event Tap；不修改或吞掉任何系统事件。
@MainActor
final class InputEventTap: EventSource {
    let events: AsyncStream<InputEvent>
    let failures: AsyncStream<EventSourceError>
    private(set) var isRunning = false
    private(set) var epoch: UInt64 = 0
    private(set) var lastError: EventSourceError?

    private let relay: InputEventRelay
    private let failureContinuation: AsyncStream<EventSourceError>.Continuation
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var wantsToRun = false
    private var restartPending = false

    init() {
        let relay = InputEventRelay()
        self.relay = relay
        events = relay.stream
        let (failures, failureContinuation) = AsyncStream<EventSourceError>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        self.failures = failures
        self.failureContinuation = failureContinuation

        relay.setRestartHandler { [weak self] in
            Task { @MainActor in
                self?.restartAfterSystemDisable()
            }
        }
    }

    func start() throws {
        wantsToRun = true
        lastError = nil

        guard AXIsProcessTrusted() else {
            wantsToRun = false
            let error = EventSourceError.accessibilityPermissionRequired
            lastError = error
            throw error
        }

        if let eventTap, CGEvent.tapIsEnabled(tap: eventTap) {
            isRunning = true
            epoch &+= 1
            relay.startAccepting(epoch: epoch)
            return
        }

        tearDownTap()
        do {
            try installTap()
            epoch &+= 1
            relay.startAccepting(epoch: epoch)
            isRunning = true
        } catch let error as EventSourceError {
            wantsToRun = false
            lastError = error
            throw error
        }
    }

    func stop() {
        wantsToRun = false
        restartPending = false
        isRunning = false
        epoch &+= 1
        relay.stopAccepting()
        tearDownTap()
    }

    private func installTap() throws {
        let eventMask = eventMask(for: [.flagsChanged, .mouseMoved])
        let context = Unmanaged.passUnretained(relay).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: ordoEventTapCallback,
            userInfo: context
        ) else {
            throw EventSourceError.eventTapCreationFailed
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            throw EventSourceError.runLoopSourceCreationFailed
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func tearDownTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        isRunning = false
    }

    private func restartAfterSystemDisable() {
        guard wantsToRun, !restartPending else {
            return
        }
        restartPending = true
        defer { restartPending = false }
        epoch &+= 1
        relay.stopAccepting()
        isRunning = false

        guard AXIsProcessTrusted() else {
            reportFailure(.accessibilityPermissionRequired)
            relay.stopAccepting()
            tearDownTap()
            return
        }

        if let eventTap, CFMachPortIsValid(eventTap) {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            if CGEvent.tapIsEnabled(tap: eventTap) {
                relay.startAccepting(epoch: epoch)
                isRunning = true
                return
            }
        }

        tearDownTap()
        do {
            try installTap()
            relay.startAccepting(epoch: epoch)
            isRunning = true
            lastError = nil
        } catch let error as EventSourceError {
            relay.stopAccepting()
            reportFailure(error)
        } catch {
            relay.stopAccepting()
            reportFailure(.eventTapCreationFailed)
        }
    }

    private func reportFailure(_ error: EventSourceError) {
        lastError = error
        failureContinuation.yield(error)
    }

    private func eventMask(for types: [CGEventType]) -> CGEventMask {
        types.reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << CGEventMask(type.rawValue))
        }
    }
}

/// C 回调只进入这个小型中继：flags 立即记录，mouseMoved 只覆盖最新值。
private final class InputEventRelay: @unchecked Sendable {
    let stream: AsyncStream<InputEvent>

    private let continuation: AsyncStream<InputEvent>.Continuation
    private let lock = NSLock()
    private let deliveryQueue = DispatchQueue(
        label: "com.ghost7.Ordo.InputEventTap.coalescing",
        qos: .userInteractive
    )

    private var isAccepting = false
    private var currentEpoch: UInt64 = 0
    private var latestMouseEvent: InputEvent?
    private var flushScheduled = false
    private var restartHandler: (@Sendable () -> Void)?

    init() {
        let (stream, continuation) = AsyncStream<InputEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(16)
        )
        self.stream = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    func setRestartHandler(_ handler: @escaping @Sendable () -> Void) {
        lock.withLock {
            restartHandler = handler
        }
    }

    func startAccepting(epoch: UInt64) {
        lock.withLock {
            currentEpoch = epoch
            latestMouseEvent = nil
            isAccepting = true
        }
    }

    func stopAccepting() {
        lock.withLock {
            isAccepting = false
            latestMouseEvent = nil
        }
    }

    func finish() {
        stopAccepting()
        continuation.finish()
    }

    func record(type: CGEventType, event: CGEvent) {
        let kind: InputEventKind
        switch type {
        case .flagsChanged:
            kind = .flagsChanged
        case .mouseMoved:
            kind = .mouseMoved
        default:
            return
        }

        let inputEvent = InputEvent(
            kind: kind,
            modifiers: ModifierChord(eventFlags: event.flags),
            location: event.location,
            timestamp: event.timestamp,
            sourceEpoch: lock.withLock { currentEpoch }
        )

        if kind == .flagsChanged {
            lock.withLock {
                guard isAccepting else { return }
                // 松键前先提交最后一个鼠标位置，避免窗口停在上一帧。
                if let pendingMouseEvent = latestMouseEvent {
                    latestMouseEvent = nil
                    continuation.yield(pendingMouseEvent)
                }
                continuation.yield(inputEvent)
            }
        } else {
            let shouldSchedule = lock.withLock { () -> Bool in
                if isAccepting {
                    latestMouseEvent = inputEvent
                    if !flushScheduled {
                        flushScheduled = true
                        return true
                    }
                }
                return false
            }
            if shouldSchedule {
                deliveryQueue.asyncAfter(deadline: .now() + .milliseconds(16)) { [weak self] in
                    self?.flushLatestMouseEvent()
                }
            }
        }
    }

    func requestRestart() {
        let handler = lock.withLock { restartHandler }
        handler?()
    }

    private func flushLatestMouseEvent() {
        lock.withLock {
            flushScheduled = false
            guard isAccepting else {
                latestMouseEvent = nil
                return
            }
            if let event = latestMouseEvent {
                latestMouseEvent = nil
                // 与 flagsChanged 共用同一临界区，锁获取顺序即 AsyncStream 交付顺序。
                continuation.yield(event)
            }
        }
    }
}

private func ordoEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let relay = Unmanaged<InputEventRelay>.fromOpaque(userInfo).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        relay.requestRestart()
        return nil
    }

    relay.record(type: type, event: event)
    return Unmanaged.passUnretained(event)
}
