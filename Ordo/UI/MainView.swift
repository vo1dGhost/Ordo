import AppKit
import SwiftUI

/// 分页只在当前进程中保留；首次展示由权限状态决定。
enum MainWindowPage: String, CaseIterable {
    case basic, features, about

    var title: String {
        switch self {
        case .basic: "基础"
        case .features: "功能"
        case .about: "关于"
        }
    }
}

struct MainView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Group {
            switch controller.mainWindowPage {
            case .basic: BasicSettingsView(controller: controller)
            case .features: FeatureSettingsView(controller: controller)
            case .about: AboutView()
            }
        }
        .padding(28)
        .frame(width: MainWindowBehavior.contentSize.width, height: MainWindowBehavior.contentSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(MainWindowConfigurator(controller: controller))
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onAppear {
            controller.refreshPermissions()
            controller.refreshLoginItemStatus()
        }
    }
}

struct BasicSettingsView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard {
                SettingsRow(title: "开机自启") {
                    Toggle("开机自启", isOn: Binding(
                        get: { controller.isLaunchAtLoginEnabled },
                        set: { controller.setLaunchAtLoginEnabled($0) }
                    ))
                    .labelsHidden()
                    .accessibilityIdentifier("ordo.launchAtLogin")
                    .help("登录当前用户后在后台启动 Ordo")
                }
                Divider()
                SettingsRow(title: "显示菜单栏图标") {
                    Toggle("显示菜单栏图标", isOn: Binding(
                        get: { controller.isMenuBarIconVisible },
                        set: { controller.setMenuBarIconVisible($0) }
                    ))
                    .labelsHidden()
                    .accessibilityIdentifier("ordo.menuBarIconVisible")
                    .help("隐藏后，可通过 Finder 或 Spotlight 再次打开 Ordo 主窗口")
                    .accessibilityHint("隐藏后，可通过 Finder 或 Spotlight 再次打开 Ordo 主窗口")
                }
                Divider()
                SettingsRow(title: "静默启动") {
                    Toggle("静默启动", isOn: Binding(
                        get: { controller.isSilentLaunchEnabled },
                        set: { controller.setSilentLaunchEnabled($0) }
                    ))
                    .labelsHidden()
                    .accessibilityIdentifier("ordo.silentLaunch")
                    .help("启动时不显示主窗口；运行中再次打开 Ordo 仍会显示主窗口")
                    .accessibilityHint("启动时不显示主窗口；运行中再次打开 Ordo 仍会显示主窗口")
                }
            }

            loginItemNotice
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toggleStyle(.switch)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ordo.page.basic")
    }

    @ViewBuilder
    private var loginItemNotice: some View {
        if let message = controller.loginItemErrorMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("ordo.loginItemError")
        } else if controller.loginItemStatus == .requiresApproval {
            HStack {
                Label("开机自启等待批准", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                Spacer()
                Button("打开登录项设置") { controller.openLoginItemSettings() }
                    .ordoGlassButton()
            }
            .accessibilityIdentifier("ordo.loginItemApproval")
        }
    }
}

struct FeatureSettingsView: View {
    @ObservedObject var controller: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var keyFeedback = ModifierKeyFeedback()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard {
                SettingsRow(title: "启用窗口管理") {
                    Toggle("启用窗口管理", isOn: $controller.isEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityIdentifier("ordo.enabled")
                        .accessibilityHint("关闭后，Ordo 不再响应窗口手势")
                }
                Divider()
                SettingsRow(title: "排布动画") {
                    Toggle("排布动画", isOn: Binding(
                        get: { controller.isSnapAnimationEnabled },
                        set: { controller.setSnapAnimationEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityIdentifier("ordo.snapAnimation")
                    .accessibilityHint(
                        reduceMotion
                            ? "系统已开启减少动态效果，排布动画暂时停用"
                            : "启用后，松开组合键时窗口平滑移动并调整到目标大小"
                    )
                }
                if !controller.accessibilityGranted {
                    Divider()
                    AccessibilityPermissionSection(controller: controller)
                }
            }

            SettingsCard {
                GestureSettingsView(controller: controller, pressedModifiers: keyFeedback.pressedModifiers)
            }
            Spacer(minLength: 0)

            statusNotice
                .padding(.horizontal, 14)
                .frame(height: 48, alignment: .topLeading)

            Button("重置快捷键", role: .destructive) {
                controller.resetGestureSettingsToDefaults()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 14)
            .accessibilityIdentifier("ordo.resetGestureSettings")
            .accessibilityHint("仅恢复三组默认快捷键")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ordo.page.features")
        .modifier(ModifierKeyFeedbackObserver(feedback: $keyFeedback))
    }

    private var statusNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            if let message = controller.shortcutValidationMessage ?? controller.statusMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(controller.shortcutValidationMessage == nil ? Color.orange : .red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(
                        controller.shortcutValidationMessage == nil ? "ordo.statusMessage" : "ordo.shortcutValidation"
                    )
                Spacer(minLength: 0)
                if controller.shortcutValidationMessage == nil {
                    Button { controller.clearStatus() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("关闭运行提示")
                        .accessibilityIdentifier("ordo.dismissStatus")
                }
            } else {
                Color.clear.accessibilityHidden(true)
            }
        }
    }

}

struct AboutView: View {
    private let bundle = Bundle.main
    private let projectURL = URL(string: "https://github.com/vo1dGhost/Ordo")!

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityLabel("Ordo App 图标")

            Text("Ordo")
                .font(.system(size: 26, weight: .semibold))
            Text(versionText)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("ordo.about.version")

            Link("GitHub 项目", destination: projectURL)
                .ordoGlassButton()
                .padding(.top, 8)
                .help(projectURL.absoluteString)
                .accessibilityIdentifier("ordo.about.project")

            Text("© 2026 voidGhost · MIT License")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ordo.page.about")
    }

    private var versionText: String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "版本 \(version)（\(build)）"
    }
}
