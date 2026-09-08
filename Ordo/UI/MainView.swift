import SwiftUI

struct MainView: View {
    @ObservedObject var controller: AppController
    @State private var selection: MainSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(MainSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationTitle("Ordo")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detailView(for: selection ?? .overview)
        }
        .background(MainWindowConfigurator())
        .onAppear {
            controller.refreshPermissions()
        }
    }

    @ViewBuilder
    private func detailView(for section: MainSection) -> some View {
        switch section {
        case .overview:
            OverviewView(controller: controller)
        case .gestures:
            GestureSettingsView(controller: controller)
        case .activityLog:
            ActivityLogView(controller: controller)
        }
    }
}

private enum MainSection: String, CaseIterable, Identifiable {
    case overview
    case gestures
    case activityLog

    var id: Self { self }

    var title: String {
        switch self {
        case .overview:
            return "概览"
        case .gestures:
            return "窗口手势"
        case .activityLog:
            return "活动日志"
        }
    }

    var symbol: String {
        switch self {
        case .overview:
            return "gauge.with.dots.needle.50percent"
        case .gestures:
            return "rectangle.and.hand.point.up.left"
        case .activityLog:
            return "list.bullet.rectangle"
        }
    }
}

private struct OverviewView: View {
    @ObservedObject var controller: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Form {
            Section("运行") {
                Toggle("启用窗口管理", isOn: $controller.isEnabled)
                    .accessibilityHint("关闭后，Ordo 不再响应窗口手势")

                LabeledContent("当前状态") {
                    Label(operationalTitle, systemImage: operationalSymbol)
                        .foregroundStyle(operationalColor)
                        .accessibilityLabel("当前状态：\(operationalTitle)")
                }
            }

            Section {
                LabeledContent("权限") {
                    Label(
                        controller.accessibilityGranted ? "已授权" : "未授权",
                        systemImage: controller.accessibilityGranted
                            ? "checkmark.circle.fill"
                            : "exclamationmark.circle.fill"
                    )
                    .foregroundStyle(controller.accessibilityGranted ? .green : .orange)
                    .accessibilityLabel(
                        controller.accessibilityGranted
                            ? "辅助功能权限已授权"
                            : "辅助功能权限未授权"
                    )
                }

                HStack {
                    if !controller.accessibilityGranted {
                        Button("授权辅助功能") {
                            controller.requestAccessibility()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("显示 macOS 辅助功能授权提示")
                    }

                    Button("重新检查") {
                        controller.refreshPermissions()
                    }
                    .accessibilityLabel("重新检查辅助功能权限")
                }
            } header: {
                Text("辅助功能权限")
            } footer: {
                Text("窗口手势只使用辅助功能权限读写窗口位置与大小，不读取或阻止普通按键输入。")
            }

            Section("最新活动") {
                if let entry = controller.latestActivity {
                    ActivityLogRow(entry: entry)
                } else {
                    Label("本次运行尚无活动", systemImage: "clock")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("概览")
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.18),
            value: controller.accessibilityGranted
        )
    }

    private var operationalTitle: String {
        if controller.isOperational {
            return "正在运行"
        }
        if !controller.isEnabled {
            return "已暂停"
        }
        if !controller.accessibilityGranted {
            return "等待授权"
        }
        if controller.shortcutValidationMessage != nil {
            return "快捷键需要调整"
        }
        return "监听未运行"
    }

    private var operationalSymbol: String {
        if controller.isOperational {
            return "checkmark.circle.fill"
        }
        if !controller.isEnabled {
            return "pause.circle.fill"
        }
        return "exclamationmark.circle.fill"
    }

    private var operationalColor: Color {
        if controller.isOperational {
            return .green
        }
        if !controller.isEnabled {
            return .secondary
        }
        return .orange
    }
}

private struct ActivityLogView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("仅保留本次运行最近 200 条活动，不会写入磁盘。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("复制全部", systemImage: "doc.on.doc") {
                    controller.copyActivityLog()
                }
                .disabled(controller.activityLog.isEmpty)

                Button("清除", systemImage: "trash") {
                    controller.clearActivityLog()
                }
                .disabled(controller.activityLog.isEmpty)
            }
            .padding()

            Divider()

            if controller.activityLog.isEmpty {
                ContentUnavailableView(
                    "暂无活动",
                    systemImage: "list.bullet.rectangle",
                    description: Text("运行状态、权限、监听和窗口手势活动会显示在这里。")
                )
            } else {
                List(controller.activityLog.reversed()) { entry in
                    ActivityLogRow(entry: entry)
                }
            }
        }
        .navigationTitle("活动日志")
    }
}

private struct ActivityLogRow: View {
    let entry: ActivityLogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: entry.level.symbol)
                .foregroundStyle(entry.level.color)
                .frame(width: 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.message)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Text(entry.category.title)
                    Text(entry.timestamp, format: .dateTime.hour().minute().second())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.level.accessibilityTitle)，\(entry.category.title)，\(entry.message)"
        )
    }
}

private extension ActivityLevel {
    var symbol: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .info:
            return .accentColor
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .info:
            return "信息"
        case .warning:
            return "警告"
        case .error:
            return "错误"
        }
    }
}

private extension ActivityCategory {
    var title: String {
        switch self {
        case .app:
            return "应用"
        case .permission:
            return "权限"
        case .listener:
            return "监听"
        case .gesture:
            return "窗口手势"
        }
    }
}
