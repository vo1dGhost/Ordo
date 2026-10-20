import CoreGraphics
import Foundation
import os
import XCTest
@testable import Ordo

/// 创建独立 RunLoop，但不安装系统 Event Tap，也不向系统发送事件。
@MainActor
final class InputEventThreadTests: XCTestCase {
    func testInputRunsWhileMainThreadIsBlocked() {
        let relay = InputEventRelay()
        let thread = InputEventThread(relay: relay)
        let completed = DispatchSemaphore(value: 0)
        let ranOnMain = OSAllocatedUnfairLock(initialState: true)
        thread.perform {
            ranOnMain.withLock { $0 = Thread.isMainThread }
            completed.signal()
        }
        // 故意不让出主线程，输入 RunLoop 必须仍能执行。
        XCTAssertEqual(completed.wait(timeout: .now() + 1), .success)
        XCTAssertFalse(ranOnMain.withLock { $0 })
        thread.stop()
    }

    func testStopWaitsForQueuedInputAndNewEpochRejectsOldFlush() async {
        let relay = InputEventRelay()
        let thread = InputEventThread(relay: relay)
        let processed = OSAllocatedUnfairLock(initialState: false)
        relay.startAccepting(epoch: 1)
        thread.perform {
            processed.withLock { $0 = true }
            if let event = CGEvent(source: nil) {
                event.location = CGPoint(x: 1, y: 0)
                relay.record(type: .mouseMoved, event: event)
            }
        }
        relay.stopAccepting()
        thread.stop()
        XCTAssertTrue(processed.withLock { $0 })
        relay.startAccepting(epoch: 2)
        thread.perform {
            if let event = CGEvent(source: nil) {
                event.location = CGPoint(x: 2, y: 0)
                relay.record(type: .mouseMoved, event: event)
                relay.record(type: .flagsChanged, event: event)
            }
        }
        thread.stop()
        relay.finish()
        var freshEvents: [InputEvent] = []
        for await batch in relay.stream {
            freshEvents.append(contentsOf: batch.takeEvents().filter { $0.sourceEpoch == 2 })
        }
        XCTAssertEqual(freshEvents.map(\.kind), [.mouseMoved, .flagsChanged])
        XCTAssertEqual(freshEvents.map(\.location.x), [2, 2])
    }

    func testThreadReleasesRelayAfterOwnerIsDestroyed() async throws {
        weak var weakRelay: InputEventRelay?
        do {
            let relay = InputEventRelay()
            weakRelay = relay
            let thread = InputEventThread(relay: relay)
            thread.stop()
        }
        for _ in 0..<100 where weakRelay != nil { try await Task.sleep(for: .milliseconds(1)) }
        XCTAssertNil(weakRelay)
    }

    func testDestroyingOwnerKeepsRelayAliveUntilInFlightWorkFinishes() async throws {
        var relay: InputEventRelay? = InputEventRelay()
        weak var weakRelay = relay
        var thread: InputEventThread? = InputEventThread(relay: try XCTUnwrap(relay))
        let entered = DispatchSemaphore(value: 0)
        let resume = DispatchSemaphore(value: 0)
        thread?.perform {
            entered.signal()
            _ = resume.wait(timeout: .now() + 2)
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        relay = nil
        thread = nil
        XCTAssertNotNil(weakRelay)
        resume.signal()
        for _ in 0..<100 where weakRelay != nil { try await Task.sleep(for: .milliseconds(1)) }
        XCTAssertNil(weakRelay)
    }
}
