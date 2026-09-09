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

/// 一条活动记录，不包含窗口、进程或输入内容等敏感信息。
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

/// 日志同步入队，退出时等待后台写入完成；调用方无需接触文件状态。
@MainActor
protocol ActivityLogging: AnyObject {
    func append(_ entry: ActivityLogEntry)
    func finish() -> Task<Void, Never>
}

/// 测试宿主及无需记录日志的控制器使用此实现，避免写入真实用户目录。
@MainActor
final class SilentActivityLogger: ActivityLogging {
    private let completion = Task<Void, Never> {}

    func append(_ entry: ActivityLogEntry) {}
    func finish() -> Task<Void, Never> { completion }
}

enum ActivityLogFormatter {
    /// 每条记录占一行，字段及中文文案与原活动记录保持一致。
    static func plainText(
        for entry: ActivityLogEntry,
        timeZone: TimeZone = .current,
        locale: Locale = Locale(identifier: "zh_CN_POSIX")
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let timestamp = formatter.string(from: entry.timestamp)
        let message = entry.message
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "[\(timestamp)] [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(message)\n"
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
