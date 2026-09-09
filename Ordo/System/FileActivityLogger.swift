import Darwin
import Foundation
import os

@MainActor
enum ActivityLoggerFactory {
    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    static func makeDefault() -> any ActivityLogging {
        guard !isRunningTests else { return SilentActivityLogger() }
        return FileActivityLogger(
            directory: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/Ordo", isDirectory: true)
        )
    }
}

/// 主线程仅入队，独立任务是唯一文件消费者，整个写入会话持有排他锁。
@MainActor
final class FileActivityLogger: ActivityLogging {
    private let continuation: AsyncStream<ActivityLogEntry>.Continuation
    private let consumer: Task<Void, Never>
    private var acceptsEntries = true

    init(
        directory: URL,
        maximumFileSize: Int = 2 * 1_024 * 1_024,
        historyCount: Int = 4,
        reportFailure: @escaping @Sendable (String) -> Void = { message in
            Logger(subsystem: "com.ghost7.Ordo", category: "文件日志")
                .error("本次运行已停用文件日志：\(message, privacy: .private)")
        }
    ) {
        precondition(maximumFileSize > 0, "日志文件容量必须大于零")
        precondition(historyCount > 0, "日志历史份数必须大于零")
        let (stream, continuation) = AsyncStream<ActivityLogEntry>.makeStream()
        self.continuation = continuation
        consumer = Task.detached(priority: .utility) {
            var writer = FileActivityWriter(
                directory: directory,
                maximumFileSize: maximumFileSize,
                historyCount: historyCount,
                reportFailure: reportFailure
            )
            writer.prepare()
            for await entry in stream {
                writer.append(entry)
            }
            writer.finish()
        }
    }

    deinit {
        continuation.finish()
    }

    func append(_ entry: ActivityLogEntry) {
        guard acceptsEntries else { return }
        continuation.yield(entry)
    }

    func finish() -> Task<Void, Never> {
        acceptsEntries = false
        continuation.finish()
        return consumer
    }
}

/// 只由消费者任务访问，不跨隔离域共享文件描述符或可变状态。
private struct FileActivityWriter {
    let directory: URL
    let maximumFileSize: Int
    let historyCount: Int
    let reportFailure: @Sendable (String) -> Void
    private var descriptor: Int32 = -1
    private var lockDescriptor: Int32 = -1
    private var currentFileSize = 0
    private var disabled = false

    init(
        directory: URL,
        maximumFileSize: Int,
        historyCount: Int,
        reportFailure: @escaping @Sendable (String) -> Void
    ) {
        self.directory = directory
        self.maximumFileSize = maximumFileSize
        self.historyCount = historyCount
        self.reportFailure = reportFailure
    }

    mutating func prepare() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            lockDescriptor = open(
                directory.appendingPathComponent("ordo.lock").path,
                O_RDWR | O_CREAT | O_NOFOLLOW | O_NONBLOCK,
                S_IRUSR | S_IWUSR
            )
            guard lockDescriptor >= 0 else { throw posixError() }
            try requireRegularFile(lockDescriptor)
            guard flock(lockDescriptor, LOCK_EX | LOCK_NB) == 0 else { throw posixError() }
            try openCurrentFile()
        } catch {
            disable(after: error)
        }
    }

    mutating func append(_ entry: ActivityLogEntry) {
        guard !disabled else { return }
        do {
            let data = Data(ActivityLogFormatter.plainText(for: entry).utf8)
            guard data.count <= maximumFileSize else { throw POSIXError(.EFBIG) }
            // 单条记录不可拆分；已有内容加上新记录达到上限时，先轮替再写入。
            if currentFileSize > 0 && currentFileSize + data.count >= maximumFileSize {
                try rotate()
            }
            try data.withUnsafeBytes { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                var offset = 0
                while offset < buffer.count {
                    let count = Darwin.write(descriptor, baseAddress.advanced(by: offset), buffer.count - offset)
                    if count < 0 && errno == EINTR { continue }
                    guard count > 0 else { throw posixError() }
                    offset += count
                }
            }
            currentFileSize += data.count
        } catch {
            disable(after: error)
        }
    }

    mutating func finish() {
        if descriptor >= 0 {
            do {
                try synchronizeAndClose()
            } catch {
                disable(after: error)
            }
        }
        releaseDescriptors()
    }

    private mutating func openCurrentFile() throws {
        descriptor = open(fileURL().path, O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW | O_NONBLOCK, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw posixError() }
        try requireRegularFile(descriptor)
        var status = stat()
        guard fstat(descriptor, &status) == 0 else { throw posixError() }
        currentFileSize = Int(status.st_size)
    }

    private mutating func rotate() throws {
        // 只轮替已知的普通文件；同名目录或符号链接不能成为递归删除的入口。
        for index in 0...historyCount {
            _ = try regularFileExists(at: fileURL(history: index))
        }
        try synchronizeAndClose()
        let oldest = fileURL(history: historyCount)
        if try regularFileExists(at: oldest), unlink(oldest.path) != 0 {
            throw posixError()
        }
        if historyCount > 1 {
            for index in stride(from: historyCount - 1, through: 1, by: -1) {
                let source = fileURL(history: index)
                if try regularFileExists(at: source), rename(source.path, fileURL(history: index + 1).path) != 0 {
                    throw posixError()
                }
            }
        }
        guard rename(fileURL().path, fileURL(history: 1).path) == 0 else { throw posixError() }
        try openCurrentFile()
    }

    private mutating func synchronizeAndClose() throws {
        guard fsync(descriptor) == 0 else { throw posixError() }
        let closingDescriptor = descriptor
        descriptor = -1
        guard close(closingDescriptor) == 0 else { throw posixError() }
    }

    private mutating func disable(after error: any Error) {
        guard !disabled else { return }
        disabled = true
        reportFailure(error.localizedDescription)
        releaseDescriptors()
    }

    private mutating func releaseDescriptors() {
        if descriptor >= 0 {
            close(descriptor)
            descriptor = -1
        }
        if lockDescriptor >= 0 {
            flock(lockDescriptor, LOCK_UN)
            close(lockDescriptor)
            lockDescriptor = -1
        }
    }

    private func fileURL(history: Int = 0) -> URL {
        directory.appendingPathComponent(history == 0 ? "ordo.log" : "ordo.\(history).log")
    }

    private func requireRegularFile(_ descriptor: Int32) throws {
        var status = stat()
        guard fstat(descriptor, &status) == 0 else { throw posixError() }
        guard status.st_mode & S_IFMT == S_IFREG else { throw POSIXError(.EINVAL) }
    }

    private func regularFileExists(at url: URL) throws -> Bool {
        var status = stat()
        guard lstat(url.path, &status) == 0 else {
            if errno == ENOENT { return false }
            throw posixError()
        }
        guard status.st_mode & S_IFMT == S_IFREG else { throw POSIXError(.EINVAL) }
        return true
    }

    private func posixError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
