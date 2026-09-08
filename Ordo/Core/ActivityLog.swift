import Foundation

enum ActivityLevel: String, CaseIterable, Equatable, Sendable {
    case info = "信息"
    case warning = "警告"
    case error = "错误"
}

enum ActivityCategory: String, CaseIterable, Equatable, Sendable {
    case app = "应用"
    case permission = "权限"
    case listener = "监听"
    case gesture = "窗口手势"
}

/// 一条仅用于本次运行的活动记录，不包含窗口、进程或输入内容等敏感信息。
struct ActivityLogEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: ActivityLevel
    let category: ActivityCategory
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: ActivityLevel,
        category: ActivityCategory,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
    }
}

/// 仅保存在内存中的定长活动日志，内部顺序为从旧到新。
struct ActivityLog: Sendable {
    static let defaultCapacity = 200

    let capacity: Int
    private(set) var entries: [ActivityLogEntry] = []

    init(capacity: Int = ActivityLog.defaultCapacity) {
        precondition(capacity > 0, "活动日志容量必须大于零")
        self.capacity = capacity
    }

    var latest: ActivityLogEntry? {
        entries.last
    }

    var reverseChronologicalEntries: [ActivityLogEntry] {
        Array(entries.reversed())
    }

    mutating func append(_ entry: ActivityLogEntry) {
        entries.append(entry)

        let overflowCount = entries.count - capacity
        if overflowCount > 0 {
            entries.removeFirst(overflowCount)
        }
    }

    @discardableResult
    mutating func append(
        timestamp: Date = Date(),
        level: ActivityLevel,
        category: ActivityCategory,
        message: String
    ) -> ActivityLogEntry {
        let entry = ActivityLogEntry(
            timestamp: timestamp,
            level: level,
            category: category,
            message: message
        )
        append(entry)
        return entry
    }

    mutating func clear() {
        entries.removeAll(keepingCapacity: true)
    }

    /// 按界面展示顺序（最新在前）生成便于复制的稳定纯文本。
    func exportPlainText(
        timeZone: TimeZone = .current,
        locale: Locale = Locale(identifier: "zh_CN_POSIX")
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return reverseChronologicalEntries
            .map { entry in
                let timestamp = formatter.string(from: entry.timestamp)
                return "[\(timestamp)] [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(entry.message)"
            }
            .joined(separator: "\n")
    }
}

extension GestureOutcome {
    /// 手势日志只描述操作结果，不包含窗口/App 身份、几何或输入数据。
    var activityDescription: String {
        switch self {
        case .moved:
            return "已移动窗口"
        case .resized:
            return "已调整窗口大小"
        case let .snapped(layout):
            return "已应用\(layout.activityTitle)排布"
        }
    }
}

private extension SnapLayout {
    var activityTitle: String {
        switch self {
        case .topLeft: "左上角"
        case .top: "铺满可见区域"
        case .topRight: "右上角"
        case .right: "右半屏"
        case .bottomRight: "右下角"
        case .bottom: "居中百分之七十五"
        case .bottomLeft: "左下角"
        case .left: "左半屏"
        }
    }
}
