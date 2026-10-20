import Foundation

/// 输入合并与排布动画共用 120 Hz 目标；实际吞吐受鼠标、系统调度和 AX 响应时间限制。
enum WindowUpdateTiming {
    // 向上取整到纳秒，避免在 200 ms 动画终点前重复采样。
    static let intervalNanoseconds = 8_333_334
    static let interval = Duration.nanoseconds(intervalNanoseconds)
}
