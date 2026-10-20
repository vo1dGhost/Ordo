import ApplicationServices
import CoreGraphics
import Foundation

enum InputEventKind: Sendable, Equatable {
    case flagsChanged
    case mouseMoved
    // 仅由内部缓冲产生，用于在严重阻塞时取消手势，不订阅额外系统事件。
    case inputOverflow
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
    var events: AsyncStream<InputEventBatch> { get }
    var failures: AsyncStream<EventSourceError> { get }
    var isRunning: Bool { get }
    var epoch: UInt64 { get }
    var lastError: EventSourceError? { get }
    /// 输入连续性中断时，在重新接收事件之前同步通知消费者取消旧任务。
    var onInterruption: (@MainActor () -> Void)? { get set }

    func start() throws
    func stop()
}

/// listen-only 的 Session Event Tap；不修改或吞掉任何系统事件。
@MainActor
final class InputEventTap: EventSource {
    let events: AsyncStream<InputEventBatch>
    let failures: AsyncStream<EventSourceError>
    private(set) var isRunning = false
    private(set) var epoch: UInt64 = 0
    private(set) var lastError: EventSourceError?
    var onInterruption: (@MainActor () -> Void)?

    private let relay: InputEventRelay
    private let failureContinuation: AsyncStream<EventSourceError>.Continuation
    private var inputThread: InputEventThread?
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

        relay.setRestartHandler { [weak self] sourceEpoch in
            Task { @MainActor in
                guard let self, self.epoch == sourceEpoch else { return }
                self.restartAfterSystemDisable()
            }
        }
    }

    func start() throws {
        wantsToRun = true
        lastError = nil
        relay.stopAccepting()
        // 重建前等待输入线程上的旧回调结束，随后才启用新 epoch。
        tearDownTap()

        guard AXIsProcessTrusted() else {
            wantsToRun = false
            let error = EventSourceError.accessibilityPermissionRequired
            lastError = error
            throw error
        }

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
        if inputThread == nil { inputThread = InputEventThread(relay: relay) }
        try inputThread?.install()
    }

    private func tearDownTap() {
        inputThread?.stop()
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
        // 同步取消窗口任务；异步事件流或下一条输入都来不及阻止已排队的最终写入。
        onInterruption?()

        guard AXIsProcessTrusted() else {
            reportFailure(.accessibilityPermissionRequired)
            relay.stopAccepting()
            tearDownTap()
            return
        }

        if inputThread?.reenableIfValid() == true {
            relay.startAccepting(epoch: epoch)
            isRunning = true
            return
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
}

/// C 回调只进入这个小型中继：flags 立即记录，mouseMoved 只覆盖最新值。
final class InputEventRelay: @unchecked Sendable {
    let stream: AsyncStream<InputEventBatch>

    private let continuation: AsyncStream<InputEventBatch>.Continuation
    private let lock = NSLock()
    private static let deliveryQueue = DispatchQueue(
        label: "com.ghoooooost.Ordo.InputEventTap.coalescing",
        qos: .userInteractive
    )
    private let now: @Sendable () -> DispatchTime
    private let scheduleMouseFlush: @Sendable (DispatchTime, @escaping @Sendable () -> Void) -> Void

    private var isAccepting = false
    private var currentEpoch: UInt64 = 0
    private var latestMouseEvent: InputEvent?
    private var pendingBatch: InputEventBatch?
    private var flushScheduled = false
    private var flushGeneration: UInt64 = 0
    private var lastMouseDelivery: DispatchTime?
    private var restartHandler: (@Sendable (UInt64) -> Void)?

    init(
        now: @escaping @Sendable () -> DispatchTime = { .now() },
        scheduleMouseFlush: @escaping @Sendable (DispatchTime, @escaping @Sendable () -> Void) -> Void = {
            deadline, action in
            InputEventRelay.deliveryQueue.asyncAfter(deadline: deadline, execute: action)
        }
    ) {
        self.now = now
        self.scheduleMouseFlush = scheduleMouseFlush
        let (stream, continuation) = AsyncStream<InputEventBatch>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        self.stream = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    func setRestartHandler(_ handler: @escaping @Sendable (UInt64) -> Void) {
        lock.withLock {
            restartHandler = handler
        }
    }

    func startAccepting(epoch: UInt64) {
        lock.withLock {
            currentEpoch = epoch
            _ = pendingBatch?.takeEvents()
            pendingBatch = nil
            latestMouseEvent = nil
            flushScheduled = false
            flushGeneration &+= 1
            lastMouseDelivery = nil
            isAccepting = true
        }
    }

    func stopAccepting() {
        lock.withLock {
            stopAcceptingLocked()
            _ = pendingBatch?.takeEvents()
            pendingBatch = nil
        }
    }

    func finish() {
        lock.withLock {
            // 已交付的批次仍可读完；尚未到采样周期的鼠标位置不补发。
            stopAcceptingLocked()
            continuation.finish()
        }
    }

    private func stopAcceptingLocked() {
        isAccepting = false
        latestMouseEvent = nil
        flushScheduled = false
        flushGeneration &+= 1
        lastMouseDelivery = nil
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

        if kind == .flagsChanged {
            lock.withLock {
                guard isAccepting else { return }
                let inputEvent = inputEvent(kind: kind, event: event)
                // 松键前先提交最后一个鼠标位置，避免窗口停在上一帧。
                if let pendingMouseEvent = latestMouseEvent {
                    latestMouseEvent = nil
                    flushScheduled = false
                    flushGeneration &+= 1
                    lastMouseDelivery = now()
                    enqueue(pendingMouseEvent)
                }
                enqueue(inputEvent)
            }
        } else {
            let scheduled = lock.withLock { () -> (deadline: DispatchTime, generation: UInt64)? in
                guard isAccepting else { return nil }
                latestMouseEvent = inputEvent(kind: kind, event: event)
                guard !flushScheduled else { return nil }
                flushScheduled = true
                flushGeneration &+= 1
                let currentTime = now()
                // 首个位置立即入队；后续只等待当前周期的剩余时间，避免每批再等完整一帧。
                let deadline = lastMouseDelivery.map {
                    DispatchTime(uptimeNanoseconds: max(
                        currentTime.uptimeNanoseconds,
                        $0.uptimeNanoseconds + UInt64(WindowUpdateTiming.intervalNanoseconds)
                    ))
                } ?? currentTime
                return (deadline, flushGeneration)
            }
            if let scheduled {
                scheduleMouseFlush(scheduled.deadline) { [weak self] in
                    self?.flushLatestMouseEvent(generation: scheduled.generation)
                }
            }
        }
    }

    func requestRestart() {
        let request = lock.withLock { () -> ((@Sendable (UInt64) -> Void), UInt64)? in
            guard isAccepting, let restartHandler else { return nil }
            return (restartHandler, currentEpoch)
        }
        if let (handler, epoch) = request { handler(epoch) }
    }

    /// 调用方持有 lock，epoch 与是否接收的检查保持原子性。
    private func inputEvent(kind: InputEventKind, event: CGEvent) -> InputEvent {
        InputEvent(
            kind: kind,
            modifiers: ModifierChord(eventFlags: event.flags),
            location: event.location,
            timestamp: event.timestamp,
            sourceEpoch: currentEpoch
        )
    }

    private func flushLatestMouseEvent(generation: UInt64) {
        lock.withLock {
            guard generation == flushGeneration else { return }
            flushScheduled = false
            guard isAccepting else {
                latestMouseEvent = nil
                return
            }
            if let event = latestMouseEvent {
                latestMouseEvent = nil
                lastMouseDelivery = now()
                enqueue(event)
            }
        }
    }

    /// 调用方持有 lock；始终只有一批尚未被消费者取走的输入。
    private func enqueue(_ event: InputEvent) {
        if pendingBatch?.append(event) == true { return }
        let batch = InputEventBatch([event])
        pendingBatch = batch
        continuation.yield(batch)
    }
}

func ordoEventTapCallback(
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
