import CoreGraphics
import Foundation
import os
import XCTest
@testable import Ordo

/// 只向中继传入内存中的 CGEvent，不安装 Event Tap、不向系统发送事件。
@MainActor
final class InputEventRelayTests: XCTestCase {
    private let interval: UInt64 = 8_333_334

    func testSeverelyBlockedConsumerCancelsWithinBoundedStorage() async throws {
        let clock = MouseDeliveryClock()
        let relay = makeRelay(clock)
        relay.startAccepting(epoch: 7)
        for x in 0..<(InputEventBatch.capacity * 2) {
            try recordMouse(x, into: relay)
            clock.runNext()
        }
        let release = try XCTUnwrap(CGEvent(source: nil))
        release.flags = []
        relay.record(type: .flagsChanged, event: release)
        let events = await finishAndCollect(relay)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .inputOverflow)
        XCTAssertEqual(events.first?.modifiers, [])
        XCTAssertEqual(events.first?.sourceEpoch, 7)
    }

    func testBatchIncludesInputArrivingAfterStreamResumesButBeforeConsumerRuns() async throws {
        let clock = MouseDeliveryClock()
        let relay = makeRelay(clock)
        relay.startAccepting(epoch: 1)
        try recordMouse(0, into: relay)
        clock.runNext()
        var iterator = relay.stream.makeAsyncIterator()
        let delivered = await iterator.next()
        let batch = try XCTUnwrap(delivered)

        // next() 已返回不代表主执行器已经恢复；此时到达的位置也必须一起取出。
        for x in 1...40 {
            try recordMouse(x, into: relay)
            clock.runNext()
        }
        XCTAssertEqual(batch.takeEvents().map(\.location.x), (0...40).map(CGFloat.init))
        XCTAssertTrue(batch.takeEvents().isEmpty)

        try recordMouse(41, into: relay)
        clock.runNext()
        let next = await iterator.next()
        XCTAssertEqual(next?.takeEvents().map(\.location.x), [41])
        relay.finish()
    }

    func testSlowConsumerPreservesModifierBoundariesAndTheWholeSampledPath() async throws {
        let clock = MouseDeliveryClock()
        let relay = makeRelay(clock)
        relay.startAccepting(epoch: 1)
        let flags = try XCTUnwrap(CGEvent(source: nil))
        flags.flags = [.maskControl, .maskShift]
        relay.record(type: .flagsChanged, event: flags)
        for x in 0..<80 {
            try recordMouse(x, into: relay)
            clock.runNext()
        }
        flags.flags = []
        relay.record(type: .flagsChanged, event: flags)
        flags.flags = [.maskAlternate, .maskShift]
        relay.record(type: .flagsChanged, event: flags)
        let events = await finishAndCollect(relay)
        XCTAssertEqual(events.count, 83)
        XCTAssertEqual(events.first?.modifiers, .defaultMove)
        XCTAssertEqual(events.filter { $0.kind == .mouseMoved }.map(\.location.x), (0..<80).map(CGFloat.init))
        XCTAssertEqual(events.suffix(2).map(\.modifiers), [[], .defaultResize])
    }

    func testStopInvalidatesBatchAlreadyDeliveredToSuspendedConsumer() async throws {
        let clock = MouseDeliveryClock()
        let relay = makeRelay(clock)
        relay.startAccepting(epoch: 1)
        try recordMouse(1, into: relay)
        clock.runNext()
        var iterator = relay.stream.makeAsyncIterator()
        let oldBatch = await iterator.next()
        relay.stopAccepting()
        relay.startAccepting(epoch: 2)
        try recordMouse(2, into: relay)
        clock.runNext()
        XCTAssertEqual(oldBatch?.takeEvents(), [])
        let freshBatch = await iterator.next()
        let events = freshBatch?.takeEvents()
        XCTAssertEqual(events?.map(\.location.x), [2])
        XCTAssertEqual(events?.map(\.sourceEpoch), [2])
        relay.finish()
    }

    func testDisabledTapNotificationAfterStopDoesNotRequestRestart() {
        let relay = InputEventRelay()
        let count = OSAllocatedUnfairLock(initialState: 0)
        relay.setRestartHandler { _ in count.withLock { $0 += 1 } }
        relay.startAccepting(epoch: 1)
        relay.stopAccepting()
        relay.requestRestart()
        XCTAssertEqual(count.withLock { $0 }, 0)
        relay.finish()
    }

    func testRestartRequestsCarryTheEpochAtNotificationTime() {
        let relay = InputEventRelay()
        let epochs = OSAllocatedUnfairLock(initialState: [UInt64]())
        relay.setRestartHandler { epoch in epochs.withLock { $0.append(epoch) } }
        relay.startAccepting(epoch: 10)
        relay.requestRestart()
        relay.stopAccepting()
        relay.requestRestart()
        relay.startAccepting(epoch: 12)
        relay.requestRestart()
        XCTAssertEqual(epochs.withLock { $0 }, [10, 12])
        relay.finish()
    }

    func testFirstMousePositionIsImmediateAndBurstsKeepOnlyLatestPosition() async throws {
        let clock = MouseDeliveryClock()
        let relay = makeRelay(clock)
        relay.startAccepting(epoch: 1)
        try recordMouse(0, into: relay)
        XCTAssertEqual(clock.deadlines, [clock.origin])
        clock.runNext()

        for millisecond in 1...6 {
            clock.setElapsed(UInt64(millisecond) * 1_000_000)
            try recordMouse(millisecond, into: relay)
        }
        assertDeadlines(clock.deadlines, [clock.origin + interval])
        clock.runNext()
        let events = await finishAndCollect(relay)
        XCTAssertEqual(events.map(\.location.x), [0, 6])
    }

    func testIdleMousePositionDoesNotWaitAnotherFullInterval() async throws {
        let clock = MouseDeliveryClock()
        let relay = makeRelay(clock)
        relay.startAccepting(epoch: 1)
        try recordMouse(0, into: relay)
        clock.runNext()
        clock.setElapsed(25_000_000)
        try recordMouse(25, into: relay)
        XCTAssertEqual(clock.deadlines, [clock.origin + 25_000_000])
        clock.runNext()
        let events = await finishAndCollect(relay)
        XCTAssertEqual(events.map(\.location.x), [0, 25])
    }

    func testLateDeliverySkipsOldPositionsAndDoesNotCatchUp() async throws {
        let clock = MouseDeliveryClock()
        let relay = makeRelay(clock)
        relay.startAccepting(epoch: 1)
        try recordMouse(0, into: relay)
        clock.runNext()
        for millisecond in 1...40 {
            clock.setElapsed(UInt64(millisecond) * 1_000_000)
            try recordMouse(millisecond, into: relay)
        }
        // 模拟调度被阻塞 40 ms，只交付最新位置，不重放错过的时间格。
        XCTAssertEqual(clock.deadlines.count, 1)
        clock.runNext()
        clock.setElapsed(41_000_000)
        try recordMouse(41, into: relay)
        assertDeadlines(clock.deadlines, [clock.origin + 40_000_000 + interval])
        clock.runNext()
        let events = await finishAndCollect(relay)
        XCTAssertEqual(events.map(\.location.x), [0, 40, 41])
    }

    func testModifierReleaseFlushesLatestPositionBeforeFlagsAndInvalidatesOldTimer() async throws {
        let clock = MouseDeliveryClock()
        let relay = makeRelay(clock)
        relay.startAccepting(epoch: 1)
        try recordMouse(0, into: relay)
        clock.runNext()
        clock.setElapsed(2_000_000)
        try recordMouse(2, into: relay)
        clock.setElapsed(3_000_000)
        let release = try XCTUnwrap(CGEvent(source: nil))
        release.flags = []
        relay.record(type: .flagsChanged, event: release)

        clock.setElapsed(4_000_000)
        try recordMouse(4, into: relay)
        assertDeadlines(clock.deadlines, [clock.origin + interval, clock.origin + 3_000_000 + interval])
        clock.runNext() // 已失效的旧回调不能提前交付新一轮鼠标事件。
        let events = await finishAndCollect(relay)
        XCTAssertEqual(events.map(\.kind), [.mouseMoved, .mouseMoved, .flagsChanged])
        XCTAssertEqual(events.prefix(2).map(\.location.x), [0, 2])
        XCTAssertEqual(events.last?.modifiers, [])
    }

    func testStopAndNewEpochDiscardOldScheduledDelivery() async throws {
        let clock = MouseDeliveryClock()
        let relay = makeRelay(clock)
        relay.startAccepting(epoch: 1)
        try recordMouse(1, into: relay)
        relay.stopAccepting()
        try recordMouse(999, into: relay)
        relay.startAccepting(epoch: 2)
        try recordMouse(2, into: relay)
        clock.runNext()
        clock.runNext()
        let events = await finishAndCollect(relay)
        XCTAssertEqual(events.map(\.location.x), [2])
        XCTAssertEqual(events.map(\.sourceEpoch), [2])
    }

    func testOneKilohertzInputProducesOneHundredTwentyDeliveriesPerSecond() async throws {
        let clock = MouseDeliveryClock()
        let relay = makeRelay(clock)
        relay.startAccepting(epoch: 1)
        var iterator = relay.stream.makeAsyncIterator()
        var events: [InputEvent] = []
        for millisecond in 0..<1_000 {
            let elapsed = UInt64(millisecond) * 1_000_000
            for _ in 0..<clock.runThrough(elapsed) {
                if let batch = await iterator.next() { events.append(contentsOf: batch.takeEvents()) }
            }
            try recordMouse(millisecond, into: relay)
        }
        for _ in 0..<clock.runThrough(1_000_000_000) {
            if let batch = await iterator.next() { events.append(contentsOf: batch.takeEvents()) }
        }
        relay.finish()
        XCTAssertEqual(events.count, 120)
        XCTAssertEqual(events.first?.location.x, 0)
        XCTAssertEqual(events.last?.location.x, 991)
    }

    private func makeRelay(_ clock: MouseDeliveryClock) -> InputEventRelay {
        InputEventRelay(
            now: { clock.now },
            scheduleMouseFlush: { deadline, action in clock.schedule(deadline, action: action) }
        )
    }

    private func assertDeadlines(
        _ actual: [UInt64],
        _ expected: [UInt64],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (actualTime, expectedTime) in zip(actual, expected) {
            // DispatchTime 按硬件时钟刻度量化；允许不足 1 微秒的舍入差异。
            XCTAssertEqual(Double(actualTime), Double(expectedTime), accuracy: 1_000, file: file, line: line)
        }
    }

    private func recordMouse(_ x: Int, into relay: InputEventRelay) throws {
        let event = try XCTUnwrap(CGEvent(source: nil))
        event.location = CGPoint(x: x, y: 0)
        event.flags = [.maskControl, .maskShift]
        relay.record(type: .mouseMoved, event: event)
    }

    private func finishAndCollect(_ relay: InputEventRelay) async -> [InputEvent] {
        relay.finish()
        var events: [InputEvent] = []
        for await batch in relay.stream { events.append(contentsOf: batch.takeEvents()) }
        return events
    }
}

private final class MouseDeliveryClock: Sendable {
    let origin: UInt64 = 1_000_000_000
    private struct Job: Sendable {
        let deadline: DispatchTime
        let action: @Sendable () -> Void
    }
    private struct State {
        var time: UInt64 = 1_000_000_000
        var jobs: [Job] = []
    }
    private let state = OSAllocatedUnfairLock(initialState: State())

    var now: DispatchTime { state.withLock { DispatchTime(uptimeNanoseconds: $0.time) } }
    var deadlines: [UInt64] { state.withLock { $0.jobs.map { $0.deadline.uptimeNanoseconds } } }

    func setElapsed(_ nanoseconds: UInt64) {
        state.withLock { $0.time = origin + nanoseconds }
    }

    func schedule(_ deadline: DispatchTime, action: @escaping @Sendable () -> Void) {
        state.withLock { $0.jobs.append(Job(deadline: deadline, action: action)) }
    }

    func runNext() {
        let job = state.withLock {
            let job = $0.jobs.removeFirst()
            $0.time = max($0.time, job.deadline.uptimeNanoseconds)
            return job
        }
        job.action()
    }

    func runThrough(_ elapsed: UInt64) -> Int {
        var deliveries = 0
        while let deadline = deadlines.first, deadline <= origin + elapsed {
            runNext()
            deliveries += 1
        }
        setElapsed(elapsed)
        return deliveries
    }
}
