import Foundation
import XCTest
@testable import Ordo

final class ActivityLogTests: XCTestCase {
    func testDefaultCapacityDropsOldestEntries() {
        var log = ActivityLog()

        for index in 1...205 {
            log.append(
                ActivityLogEntry(
                    timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                    level: .info,
                    category: .app,
                    message: "第 \(index) 条活动"
                )
            )
        }

        XCTAssertEqual(log.capacity, 200)
        XCTAssertEqual(log.entries.count, 200)
        XCTAssertEqual(log.entries.first?.message, "第 6 条活动")
        XCTAssertEqual(log.latest?.message, "第 205 条活动")
    }

    func testReverseChronologicalEntriesReturnsNewestFirst() {
        var log = ActivityLog(capacity: 3)
        let first = makeEntry(second: 1, message: "先启动")
        let second = makeEntry(second: 2, message: "再监听")
        let third = makeEntry(second: 3, message: "最后完成")

        log.append(first)
        log.append(second)
        log.append(third)

        XCTAssertEqual(log.entries, [first, second, third])
        XCTAssertEqual(log.reverseChronologicalEntries, [third, second, first])
        XCTAssertEqual(log.latest, third)
    }

    func testClearRemovesAllEntries() {
        var log = ActivityLog(capacity: 2)
        log.append(makeEntry(second: 1, message: "Ordo 已启动"))

        log.clear()

        XCTAssertTrue(log.entries.isEmpty)
        XCTAssertTrue(log.reverseChronologicalEntries.isEmpty)
        XCTAssertNil(log.latest)
        XCTAssertEqual(log.exportPlainText(), "")
    }

    func testPlainTextExportUsesStableChineseFormatAndNewestFirst() throws {
        var log = ActivityLog(capacity: 2)
        log.append(
            ActivityLogEntry(
                id: try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
                timestamp: Date(timeIntervalSince1970: 0),
                level: .info,
                category: .app,
                message: "Ordo 已启动"
            )
        )
        log.append(
            ActivityLogEntry(
                id: try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002")),
                timestamp: Date(timeIntervalSince1970: 1),
                level: .warning,
                category: .listener,
                message: "窗口手势监听已停止"
            )
        )

        let text = log.exportPlainText(
            timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 8 * 60 * 60)),
            locale: Locale(identifier: "zh_CN_POSIX")
        )

        XCTAssertEqual(
            text,
            """
            [1970-01-01 08:00:01] [警告] [监听] 窗口手势监听已停止
            [1970-01-01 08:00:00] [信息] [应用] Ordo 已启动
            """
        )
    }

    func testGestureDescriptionsContainOnlyGenericOutcomes() {
        XCTAssertEqual(GestureOutcome.moved.activityDescription, "已移动窗口")
        XCTAssertEqual(GestureOutcome.resized.activityDescription, "已调整窗口大小")
        XCTAssertEqual(GestureOutcome.snapped(.right).activityDescription, "已应用右半屏排布")

        let descriptions = [
            GestureOutcome.moved.activityDescription,
            GestureOutcome.resized.activityDescription,
            GestureOutcome.snapped(.bottom).activityDescription,
        ].joined(separator: " ")
        for sensitiveToken in ["PID", "App", "frame", "鼠标", "按键", "快捷键"] {
            XCTAssertFalse(descriptions.localizedCaseInsensitiveContains(sensitiveToken))
        }
    }

    func testEntrySchemaHasNoWindowOrInputIdentityFields() {
        let entry = makeEntry(second: 1, message: "已移动窗口")
        let fieldNames = Set(Mirror(reflecting: entry).children.compactMap(\.label))

        XCTAssertEqual(fieldNames, ["id", "timestamp", "level", "category", "message"])
        XCTAssertTrue(fieldNames.isDisjoint(with: [
            "pid", "windowName", "applicationName", "frame", "mouseLocation",
            "keyCode", "keyValue", "keyCount",
        ]))
    }

    private func makeEntry(second: TimeInterval, message: String) -> ActivityLogEntry {
        ActivityLogEntry(
            timestamp: Date(timeIntervalSince1970: second),
            level: .info,
            category: .app,
            message: message
        )
    }
}
