import AppKit
import Security

// 仅供本地更新命令使用，不加入 App target，也不请求任何隐私权限。
@main
enum AppLifecycle {
    private static let bundleID = "com.ghoooooost.Ordo"
    private static let teamID = "ND3SVRRF43"

    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    @MainActor
    private final class LaunchResult {
        var value: Result<NSRunningApplication, Error>?
    }

    @MainActor
    static func main() {
        do {
            let arguments = CommandLine.arguments
            guard arguments.count >= 3 else { throw Failure("缺少操作和 App 路径。") }
            let url = URL(fileURLWithPath: arguments[2]).standardizedFileURL
            switch arguments[1] {
            case "verify":
                try verify(url)
            case "check":
                let pids = try instances(at: url).map { String($0.processIdentifier) }.sorted()
                print(pids.isEmpty ? "-" : pids.joined(separator: ","))
            case "stop", "launch":
                guard arguments.count == 4 else { throw Failure("缺少进程快照。") }
                let pids = Set(arguments[3].split(separator: ",").compactMap { Int32($0) })
                if arguments[1] == "stop" {
                    try stop(url, expectedPIDs: pids)
                } else {
                    try launch(url, previousPIDs: pids)
                }
            default:
                throw Failure("未知操作。")
            }
        } catch {
            FileHandle.standardError.write(Data("更新检查失败：\(error)\n".utf8))
            exit(1)
        }
    }

    private static func verify(_ url: URL) throws {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              let code else { throw Failure("无法读取候选 App 的签名。") }
        // 验证 Apple 开发证书链与真实团队，拒绝临时签名及其他签名类别。
        let expression = "identifier \"\(bundleID)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\" and certificate leaf[field.1.2.840.113635.100.6.1.2] exists"
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(expression as CFString, [], &requirement) == errSecSuccess,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures).union(.considerExpiration), requirement) == errSecSuccess
        else { throw Failure("候选必须由团队 \(teamID) 的有效 Apple Development 证书签名。") }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let info = information as? [String: Any],
              let flags = info[kSecCodeInfoFlags as String] as? NSNumber,
              flags.uint32Value & 0x10000 != 0,
              info[kSecCodeInfoTeamIdentifier as String] as? String == teamID
        else { throw Failure("候选未启用 Hardened Runtime，或签名团队不符。") }
        let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any] ?? [:]
        guard entitlements["com.apple.security.app-sandbox"] == nil else {
            throw Failure("候选不能包含 App Sandbox entitlement。")
        }
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), format: nil) as? [String: Any]
        guard plist?["CFBundleIdentifier"] as? String == bundleID,
              plist?["CFBundleExecutable"] as? String == "Ordo",
              plist?["LSUIElement"] as? Bool == true,
              plist?["LSMinimumSystemVersion"] as? String == "14.0"
        else { throw Failure("候选的 Bundle ID、可执行文件、菜单栏模式或最低系统版本不符合项目约定。") }
        print("签名与配置验证通过：Apple Development / \(teamID)")
    }

    @MainActor
    private static func instances(at url: URL) throws -> [NSRunningApplication] {
        let expected = url.resolvingSymlinksInPath()
        let executable = expected.appendingPathComponent("Contents/MacOS/Ordo")
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { !$0.isTerminated }
        for app in apps {
            guard app.bundleURL?.resolvingSymlinksInPath() == expected,
                  app.executableURL?.resolvingSymlinksInPath() == executable else {
                throw Failure("发现其他路径的 Ordo，未对其执行退出：PID \(app.processIdentifier)，\(app.executableURL?.path ?? "路径未知")。请先手动退出该副本。")
            }
        }
        return apps
    }

    @MainActor
    private static func stop(_ url: URL, expectedPIDs: Set<pid_t>) throws {
        let apps = try instances(at: url)
        guard Set(apps.map(\.processIdentifier)).isSubset(of: expectedPIDs) else {
            throw Failure("检查后出现了新的 Ordo 进程，已停止更新。")
        }
        for app in apps {
            guard app.terminate() else { throw Failure("PID \(app.processIdentifier) 拒绝正常退出，未强制终止。") }
        }
        let deadline = Date().addingTimeInterval(15)
        while apps.contains(where: { !$0.isTerminated }) && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        guard apps.allSatisfy(\.isTerminated), try instances(at: url).isEmpty else {
            throw Failure("等待旧进程清理并退出超时，未替换 App，也未强制终止进程。")
        }
    }

    @MainActor
    private static func launch(_ url: URL, previousPIDs: Set<pid_t>) throws {
        guard try instances(at: url).isEmpty else { throw Failure("启动前仍存在运行中的 Ordo。") }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = false
        // 系统回调来自并发队列，切回主 actor 后再交付给 RunLoop 轮询。
        let result = LaunchResult()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
            Task { @MainActor in
                if let error { result.value = .failure(error) }
                else if let app { result.value = .success(app) }
                else { result.value = .failure(Failure("Launch Services 未返回进程。")) }
            }
        }
        let deadline = Date().addingTimeInterval(15)
        while result.value == nil && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        guard let value = result.value else { throw Failure("等待 Launch Services 启动超时。") }
        let app = try value.get()
        guard !previousPIDs.contains(app.processIdentifier) else { throw Failure("启动返回了旧 PID。") }
        var readySince: Date?
        while Date() < deadline {
            let apps = try instances(at: url)
            guard !app.isTerminated, apps.count == 1, apps[0].processIdentifier == app.processIdentifier else {
                throw Failure("新进程已经退出，或实际启动路径/进程数量不符。")
            }
            if app.isFinishedLaunching {
                if readySince == nil { readySince = Date() }
                if Date().timeIntervalSince(readySince!) >= 2 {
                    print("启动核验通过：PID \(app.processIdentifier)，\(app.executableURL!.path)")
                    return
                }
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        throw Failure("新进程未在限定时间内完成启动。")
    }
}
