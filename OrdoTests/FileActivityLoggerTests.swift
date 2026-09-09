import Darwin
import Foundation
import os
import XCTest
@testable import Ordo

@MainActor
final class FileActivityLoggerTests: XCTestCase {
    func testFinishDrainsQueuedEntriesInAppendOrder() async throws {
        let directory = try makeDirectory()
        let logger = FileActivityLogger(directory: directory)
        let entries = (0..<300).map { entry("第 \($0) 条活动") }
        entries.forEach(logger.append)

        await logger.finish().value

        XCTAssertEqual(try text(in: directory), entries.map { ActivityLogFormatter.plainText(for: $0) }.joined())
    }

    func testSeparateRunsAppendAndReleaseTheFileLock() async throws {
        let directory = try makeDirectory()
        let first = entry("第一次启动")
        let second = entry("第二次启动")
        let firstLogger = FileActivityLogger(directory: directory)
        firstLogger.append(first)
        await firstLogger.finish().value

        let secondLogger = FileActivityLogger(directory: directory)
        secondLogger.append(second)
        await secondLogger.finish().value

        XCTAssertEqual(
            try text(in: directory),
            ActivityLogFormatter.plainText(for: first) + ActivityLogFormatter.plainText(for: second)
        )
    }

    func testRotationOccursBeforeReachingLimitAndOnlyKeepsConfiguredHistory() async throws {
        let directory = try makeDirectory()
        let unrelated = directory.appendingPathComponent("notes.txt")
        try "保留无关文件".write(to: unrelated, atomically: true, encoding: .utf8)
        let entries = (0..<7).map { entry("活动 \($0)") }
        let lineSize = ActivityLogFormatter.plainText(for: entries[0]).utf8.count
        let logger = FileActivityLogger(directory: directory, maximumFileSize: lineSize * 2)
        entries.forEach(logger.append)
        await logger.finish().value

        XCTAssertEqual(try text(in: directory), ActivityLogFormatter.plainText(for: entries[6]))
        for history in 1...4 {
            XCTAssertEqual(
                try text(in: directory, name: "ordo.\(history).log"),
                ActivityLogFormatter.plainText(for: entries[6 - history])
            )
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("ordo.5.log").path))
        XCTAssertEqual(try String(contentsOf: unrelated, encoding: .utf8), "保留无关文件")
    }

    func testEntriesRemainTogetherWhileBelowLimit() async throws {
        let directory = try makeDirectory()
        let entries = [entry("活动 1"), entry("活动 2")]
        let expected = entries.map { ActivityLogFormatter.plainText(for: $0) }.joined()
        let logger = FileActivityLogger(directory: directory, maximumFileSize: expected.utf8.count + 1)
        entries.forEach(logger.append)
        await logger.finish().value

        XCTAssertEqual(try text(in: directory), expected)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("ordo.1.log").path))
    }

    func testSingleEntryExactlyAtLimitIsPreservedAndNextEntryRotates() async throws {
        let directory = try makeDirectory()
        let first = entry("活动 1")
        let second = entry("活动 2")
        let lineSize = ActivityLogFormatter.plainText(for: first).utf8.count
        let logger = FileActivityLogger(directory: directory, maximumFileSize: lineSize)
        logger.append(first)
        logger.append(second)
        await logger.finish().value

        XCTAssertEqual(try text(in: directory), ActivityLogFormatter.plainText(for: second))
        XCTAssertEqual(try text(in: directory, name: "ordo.1.log"), ActivityLogFormatter.plainText(for: first))
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("ordo.log")).count, lineSize)
    }

    func testOversizedEntryDisablesWritingBeforeExceedingFileLimit() async throws {
        let directory = try makeDirectory()
        let first = entry("正常活动")
        let maximumFileSize = ActivityLogFormatter.plainText(for: first).utf8.count + 1
        let failures = OSAllocatedUnfairLock(initialState: 0)
        let logger = FileActivityLogger(
            directory: directory,
            maximumFileSize: maximumFileSize,
            reportFailure: { _ in failures.withLock { $0 += 1 } }
        )
        logger.append(first)
        logger.append(entry(String(repeating: "过长活动", count: 100)))
        logger.append(entry("失败后不再写入"))
        await logger.finish().value

        XCTAssertEqual(failures.withLock { $0 }, 1)
        XCTAssertEqual(try text(in: directory), ActivityLogFormatter.plainText(for: first))
        XCTAssertLessThanOrEqual(try Data(contentsOf: directory.appendingPathComponent("ordo.log")).count, maximumFileSize)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("ordo.1.log").path))
    }

    func testLockedDirectoryDisablesWritingAndReportsOnlyOnce() async throws {
        let directory = try makeDirectory()
        let lockURL = directory.appendingPathComponent("ordo.lock")
        let descriptor = open(lockURL.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        guard descriptor >= 0 else { return }
        defer { close(descriptor) }
        XCTAssertEqual(flock(descriptor, LOCK_EX | LOCK_NB), 0)
        let failures = OSAllocatedUnfairLock(initialState: 0)
        let logger = FileActivityLogger(directory: directory, reportFailure: { _ in
            failures.withLock { $0 += 1 }
        })
        for _ in 0..<5 { logger.append(entry("不会写入")) }
        await logger.finish().value

        XCTAssertEqual(failures.withLock { $0 }, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("ordo.log").path))
    }

    func testDirectoryCreationFailureIsReportedOnceWithoutBlockingFinish() async throws {
        let directory = try makeDirectory()
        let blockedDirectory = directory.appendingPathComponent("被普通文件占用")
        try "原有内容".write(to: blockedDirectory, atomically: true, encoding: .utf8)
        let failures = OSAllocatedUnfairLock(initialState: 0)
        let logger = FileActivityLogger(directory: blockedDirectory, reportFailure: { _ in
            failures.withLock { $0 += 1 }
        })
        for _ in 0..<5 { logger.append(entry("不会写入")) }
        await logger.finish().value

        XCTAssertEqual(failures.withLock { $0 }, 1)
        XCTAssertEqual(try String(contentsOf: blockedDirectory, encoding: .utf8), "原有内容")
    }

    func testUnwritableLogDisablesWritingAndDoesNotTouchOtherFiles() async throws {
        let directory = try makeDirectory()
        let logURL = directory.appendingPathComponent("ordo.log")
        try "原有内容".write(to: logURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: logURL.path)
        let failures = OSAllocatedUnfairLock(initialState: 0)
        let logger = FileActivityLogger(directory: directory, reportFailure: { _ in
            failures.withLock { $0 += 1 }
        })
        logger.append(entry("不会写入"))
        logger.append(entry("也不会写入"))
        await logger.finish().value

        XCTAssertEqual(failures.withLock { $0 }, 1)
        XCTAssertEqual(try text(in: directory), "原有内容")
    }

    func testRotationFailureStopsFurtherWritesAfterOneReport() async throws {
        let directory = try makeDirectory()
        let obstacle = directory.appendingPathComponent("ordo.1.log")
        try FileManager.default.createDirectory(at: obstacle, withIntermediateDirectories: false)
        try "不应删除".write(to: obstacle.appendingPathComponent("keep.txt"), atomically: true, encoding: .utf8)
        let first = entry("第一条")
        let failures = OSAllocatedUnfairLock(initialState: 0)
        let logger = FileActivityLogger(
            directory: directory,
            maximumFileSize: ActivityLogFormatter.plainText(for: first).utf8.count * 2,
            historyCount: 1,
            reportFailure: { _ in failures.withLock { $0 += 1 } }
        )
        logger.append(first)
        logger.append(entry("第二条"))
        logger.append(entry("第三条"))
        await logger.finish().value

        XCTAssertEqual(failures.withLock { $0 }, 1)
        XCTAssertEqual(try text(in: directory), ActivityLogFormatter.plainText(for: first))
        XCTAssertEqual(try String(contentsOf: obstacle.appendingPathComponent("keep.txt"), encoding: .utf8), "不应删除")
    }

    func testRepeatedFinishAndAppendAfterFinishAreSafe() async throws {
        let directory = try makeDirectory()
        let first = entry("结束前")
        let logger = FileActivityLogger(directory: directory)
        logger.append(first)
        let completion = logger.finish()
        logger.append(entry("结束后"))
        let repeatedCompletion = logger.finish()
        await completion.value
        await repeatedCompletion.value

        XCTAssertEqual(try text(in: directory), ActivityLogFormatter.plainText(for: first))
    }

    func testDefaultFactoryIsSilentInsideXCTestHost() async {
        XCTAssertTrue(ActivityLoggerFactory.isRunningTests)
        let logger = ActivityLoggerFactory.makeDefault()
        XCTAssertTrue(logger is SilentActivityLogger)
        logger.append(entry("测试不写入用户目录"))
        await logger.finish().value
    }

    private func makeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("build/SingleInterfaceValidation-20260909/FileLogTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func entry(_ message: String) -> ActivityLogEntry {
        ActivityLogEntry(timestamp: Date(timeIntervalSince1970: 0), level: .info, category: .app, message: message)
    }

    private func text(in directory: URL, name: String = "ordo.log") throws -> String {
        try String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
    }
}
