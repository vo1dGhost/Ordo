import os

/// 消费者真正恢复执行时才取出输入，避免慢 AX 调用之后逐个补写过期位置。
/// 同一批保留修饰键边界和径向手势路径，由主执行器一次同步处理。
final class InputEventBatch: Sendable {
    static let capacity = 1_024

    private struct State: Sendable {
        var events: [InputEvent]
        var consumed = false
        var overflowed = false
    }

    private let state: OSAllocatedUnfairLock<State>

    init(_ events: [InputEvent]) {
        if events.count > Self.capacity, let last = events.last {
            state = OSAllocatedUnfairLock(initialState: State(
                events: [Self.overflowEvent(last)],
                overflowed: true
            ))
        } else {
            state = OSAllocatedUnfairLock(initialState: State(events: events))
        }
    }

    /// 已被取走的批次不再追加；生产者应改为发送下一批。
    func append(_ event: InputEvent) -> Bool {
        state.withLock { state in
            guard !state.consumed else { return false }
            if state.overflowed || state.events.count == Self.capacity {
                // 极长阻塞时有界取消，不能丢失部分修饰键后继续执行残缺手势。
                state.overflowed = true
                state.events = [Self.overflowEvent(event)]
            } else {
                state.events.append(event)
            }
            return true
        }
    }

    func takeEvents() -> [InputEvent] {
        state.withLock { state in
            let events = state.events
            state.events.removeAll(keepingCapacity: false)
            state.consumed = true
            return events
        }
    }

    private static func overflowEvent(_ event: InputEvent) -> InputEvent {
        InputEvent(
            kind: .inputOverflow,
            modifiers: event.modifiers,
            location: event.location,
            timestamp: event.timestamp,
            sourceEpoch: event.sourceEpoch
        )
    }
}
