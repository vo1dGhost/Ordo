import Foundation
import XCTest
@testable import Ordo

final class ActivityLogTests: XCTestCase {
    func testPlainTextUsesStableChineseFieldsAndTrailingNewline() throws {
        let entry = ActivityLogEntry(
            timestamp: Date(timeIntervalSince1970: 0),
            level: .warning,
            category: .listener,
            message: "窗口手势监听已停止"
        )

        XCTAssertEqual(
            ActivityLogFormatter.plainText(
                for: entry,
                timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 8 * 60 * 60)),
                locale: Locale(identifier: "zh_CN_POSIX")
            ),
            "[1970-01-01 08:00:00] [警告] [监听] 窗口手势监听已停止\n"
        )
    }

    func testMessageLineBreaksCannotCreateAdditionalRecords() {
        let entry = ActivityLogEntry(level: .info, category: .app, message: "第一行\r\n第二行")
        let text = ActivityLogFormatter.plainText(for: entry)

        XCTAssertEqual(text.filter { $0 == "\n" }.count, 1)
        XCTAssertTrue(text.hasSuffix("第一行\\r\\n第二行\n"))
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
        let entry = ActivityLogEntry(level: .info, category: .gesture, message: "已移动窗口")
        let fieldNames = Set(Mirror(reflecting: entry).children.compactMap(\.label))

        XCTAssertEqual(fieldNames, ["id", "timestamp", "level", "category", "message"])
        XCTAssertTrue(fieldNames.isDisjoint(with: [
            "pid", "windowName", "applicationName", "frame", "mouseLocation",
            "keyCode", "keyValue", "keyCount",
        ]))
    }
}
