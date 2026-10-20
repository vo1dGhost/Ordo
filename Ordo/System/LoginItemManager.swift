import ServiceManagement

/// 登录项状态由系统管理，不以本地偏好覆盖用户在系统设置中的选择。
@MainActor
protocol LoginItemManaging {
    var status: SMAppService.Status { get }
    func setEnabled(_ enabled: Bool) throws
    func openSystemSettings()
}

@MainActor
struct SystemLoginItemManager: LoginItemManaging {
    var status: SMAppService.Status { SMAppService.mainApp.status }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
