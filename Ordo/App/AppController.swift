import AppKit
import Combine
import Foundation
import SwiftUI

/// 应用唯一状态源：持久化设置、权限状态、监听生命周期和首启引导。
@MainActor
final class AppController: ObservableObject {
    private enum PreferenceKey {
        static let enabled = "ordo.enabled"
        static let resizeChord = "ordo.shortcut.resize"
        static let snapChord = "ordo.shortcut.snap"
        static let moveChord = "ordo.shortcut.move"
        static let snapAnimationEnabled = "ordo.snap.animationEnabled"
        static let hasShownOnboarding = "ordo.onboarding.shown"
    }

    static let shared = AppController()

    @Published var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: PreferenceKey.enabled)
            if !isEnabled {
                gestureCoordinator.cancelCurrentSession()
            }
            recordActivity(
                level: .info,
                category: .app,
                message: isEnabled ? "Ordo 已启用" : "Ordo 已暂停"
            )
            reconcileMonitoring()
        }
    }

    @Published private(set) var accessibilityGranted = false
    @Published private(set) var isSnapAnimationEnabled: Bool
    @Published var resizeChord: ModifierChord {
        didSet { shortcutsDidChange() }
    }
    @Published var snapChord: ModifierChord {
        didSet { shortcutsDidChange() }
    }
    @Published var moveChord: ModifierChord {
        didSet { shortcutsDidChange() }
    }
    @Published private(set) var shortcutValidationMessage: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var monitoringActive = false
    @Published private(set) var activityLog: [ActivityLogEntry] = []

    var latestActivity: ActivityLogEntry? {
        activityLog.last
    }

    var isOperational: Bool {
        isEnabled && accessibilityGranted && shortcutValidationMessage == nil && monitoringActive
    }

    var currentSnapTransition: WindowFrameTransition {
        guard isSnapAnimationEnabled, !accessibilityReduceMotion() else {
            return .immediate
        }
        return .animated(.snapDefault)
    }

    func setSnapAnimationEnabled(_ enabled: Bool) {
        guard isSnapAnimationEnabled != enabled else { return }
        isSnapAnimationEnabled = enabled
        defaults.set(enabled, forKey: PreferenceKey.snapAnimationEnabled)
    }

    private let defaults: UserDefaults
    private let windowController: any WindowControlling
    private let screenProvider: any ScreenGeometryProviding
    private let eventSource: any EventSource
    private let previewController: any PreviewDisplaying
    private let accessibilityTrust: @MainActor (_ prompt: Bool) -> Bool
    private let accessibilityReduceMotion: @MainActor () -> Bool
    private var activityLogStore = ActivityLog()

    private lazy var gestureCoordinator = GestureCoordinator(
        windowController: windowController,
        screenProvider: screenProvider,
        previewController: previewController,
        onStatus: { [weak self] message in
            self?.recordActivity(level: .error, category: .gesture, message: message)
        },
        snapTransition: { [weak self] in
            self?.currentSnapTransition ?? .immediate
        },
        onOutcome: { [weak self] outcome in
            self?.recordGestureOutcome(outcome)
        }
    )

    private var eventTask: Task<Void, Never>?
    private var eventFailureTask: Task<Void, Never>?
    private var screenTask: Task<Void, Never>?
    private var workspaceSleepTask: Task<Void, Never>?
    private var sessionResignTask: Task<Void, Never>?
    private var permissionTimer: Timer?
    private var onboardingWindow: NSWindow?
    private var hasStarted = false
    private var lastMonitoringEligibility = false
    private var lastListenerErrorMessage: String?

    init(
        defaults: UserDefaults = .standard,
        windowController: any WindowControlling = AXWindowController(),
        screenProvider: any ScreenGeometryProviding = ScreenGeometryProvider(),
        eventSource: any EventSource = InputEventTap(),
        previewController: any PreviewDisplaying = PreviewPanelController(),
        accessibilityTrust: @escaping @MainActor (_ prompt: Bool) -> Bool = { prompt in
            AXWindowController.isAccessibilityTrusted(prompt: prompt)
        },
        accessibilityReduceMotion: @escaping @MainActor () -> Bool = {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
    ) {
        self.defaults = defaults
        self.windowController = windowController
        self.screenProvider = screenProvider
        self.eventSource = eventSource
        self.previewController = previewController
        self.accessibilityTrust = accessibilityTrust
        self.accessibilityReduceMotion = accessibilityReduceMotion

        if defaults.object(forKey: PreferenceKey.enabled) == nil {
            isEnabled = true
        } else {
            isEnabled = defaults.bool(forKey: PreferenceKey.enabled)
        }
        if defaults.object(forKey: PreferenceKey.snapAnimationEnabled) == nil {
            isSnapAnimationEnabled = true
        } else {
            isSnapAnimationEnabled = defaults.bool(forKey: PreferenceKey.snapAnimationEnabled)
        }
        resizeChord = Self.loadChord(
            key: PreferenceKey.resizeChord,
            fallback: .defaultResize,
            defaults: defaults
        )
        snapChord = Self.loadChord(
            key: PreferenceKey.snapChord,
            fallback: .defaultSnap,
            defaults: defaults
        )
        moveChord = Self.loadChord(
            key: PreferenceKey.moveChord,
            fallback: .defaultMove,
            defaults: defaults
        )

        shortcutValidationMessage = Self.validationMessage(
            resize: resizeChord,
            snap: snapChord,
            move: moveChord
        )
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        recordActivity(level: .info, category: .app, message: "Ordo 已启动")

        gestureCoordinator.updateShortcuts(
            resize: resizeChord,
            snap: snapChord,
            move: moveChord
        )

        eventTask = Task { [weak self, eventSource] in
            for await event in eventSource.events {
                guard !Task.isCancelled else { break }
                guard let self,
                      self.isEnabled,
                      self.accessibilityGranted,
                      self.monitoringActive,
                      eventSource.isRunning,
                      event.sourceEpoch == eventSource.epoch
                else {
                    continue
                }
                self.gestureCoordinator.handle(event)
            }
        }

        eventFailureTask = Task { [weak self, eventSource] in
            for await error in eventSource.failures {
                guard !Task.isCancelled else { break }
                self?.handleEventSourceFailure(error)
            }
        }

        screenTask = Task { [weak self, screenProvider] in
            var isInitialSnapshot = true
            for await _ in screenProvider.screenChanges() {
                guard !Task.isCancelled else { break }
                if isInitialSnapshot {
                    isInitialSnapshot = false
                } else {
                    self?.resetWindowInteractionForSystemChange()
                }
            }
        }

        workspaceSleepTask = Task { [weak self] in
            for await _ in NSWorkspace.shared.notificationCenter.notifications(
                named: NSWorkspace.willSleepNotification
            ) {
                guard !Task.isCancelled else { break }
                self?.handleSystemInterruption()
            }
        }

        sessionResignTask = Task { [weak self] in
            for await _ in NSWorkspace.shared.notificationCenter.notifications(
                named: NSWorkspace.sessionDidResignActiveNotification
            ) {
                guard !Task.isCancelled else { break }
                self?.handleSystemInterruption()
            }
        }

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissions()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer

        refreshPermissions()
        presentOnboardingIfNeeded()
    }

    @discardableResult
    func shutdown() -> Task<Void, Never> {
        eventTask?.cancel()
        eventTask = nil
        eventFailureTask?.cancel()
        eventFailureTask = nil
        screenTask?.cancel()
        screenTask = nil
        workspaceSleepTask?.cancel()
        workspaceSleepTask = nil
        sessionResignTask?.cancel()
        sessionResignTask = nil
        permissionTimer?.invalidate()
        permissionTimer = nil
        gestureCoordinator.cancelCurrentSession()
        eventSource.stop()
        monitoringActive = false
        return Task { [windowController] in
            await windowController.releaseAll()
        }
    }

    func requestAccessibility() {
        _ = accessibilityTrust(true)
        recordActivity(
            level: .info,
            category: .permission,
            message: "已请求辅助功能授权；授权后 Ordo 会自动开始运行"
        )
        refreshPermissions()
    }

    func refreshPermissions() {
        let granted = accessibilityTrust(false)
        if accessibilityGranted != granted {
            accessibilityGranted = granted
            if !granted {
                gestureCoordinator.cancelCurrentSession()
                recordActivity(
                    level: .warning,
                    category: .permission,
                    message: "辅助功能权限已撤销，窗口手势已停止"
                )
            } else {
                Task { [windowController] in
                    await windowController.accessibilityPermissionDidRecover()
                }
                recordActivity(
                    level: .info,
                    category: .permission,
                    message: "辅助功能权限已授权"
                )
            }
        }
        reconcileMonitoring()
    }

    func clearStatus() {
        statusMessage = nil
    }

    func clearActivityLog() {
        activityLogStore.clear()
        activityLog = []
        statusMessage = nil
    }

    func copyActivityLog() {
        let contents = activityLogStore.exportPlainText()
        guard !contents.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(contents, forType: .string)
    }

    /// 睡眠或用户会话离开时终止窗口交互并清除失效预览。
    func handleSystemInterruption() {
        resetWindowInteractionForSystemChange()
    }

    private func resetWindowInteractionForSystemChange() {
        gestureCoordinator.cancelCurrentSession()
        // 推进输入 epoch，让系统变化前排队的事件失效。
        eventSource.stop()
        monitoringActive = false
        previewController.invalidate()
        reconcileMonitoring()
    }

    func dismissOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    private func recordActivity(
        level: ActivityLevel,
        category: ActivityCategory,
        message: String
    ) {
        activityLogStore.append(level: level, category: category, message: message)
        activityLog = activityLogStore.entries
        statusMessage = message
    }

    private func recordGestureOutcome(_ outcome: GestureOutcome) {
        recordActivity(
            level: .info,
            category: .gesture,
            message: outcome.activityDescription
        )
    }

    private func shortcutsDidChange() {
        let previousMessage = shortcutValidationMessage
        shortcutValidationMessage = Self.validationMessage(
            resize: resizeChord,
            snap: snapChord,
            move: moveChord
        )

        guard shortcutValidationMessage == nil else {
            gestureCoordinator.cancelCurrentSession()
            if shortcutValidationMessage != previousMessage,
               let shortcutValidationMessage {
                recordActivity(
                    level: .warning,
                    category: .listener,
                    message: shortcutValidationMessage
                )
            }
            reconcileMonitoring()
            return
        }

        defaults.set(Int(resizeChord.rawValue), forKey: PreferenceKey.resizeChord)
        defaults.set(Int(snapChord.rawValue), forKey: PreferenceKey.snapChord)
        defaults.set(Int(moveChord.rawValue), forKey: PreferenceKey.moveChord)
        gestureCoordinator.updateShortcuts(
            resize: resizeChord,
            snap: snapChord,
            move: moveChord
        )
        reconcileMonitoring()
    }

    private func reconcileMonitoring() {
        let shouldRun = isEnabled
            && accessibilityGranted
            && shortcutValidationMessage == nil
        if shouldRun != lastMonitoringEligibility {
            lastMonitoringEligibility = shouldRun
            if shouldRun {
                lastListenerErrorMessage = nil
            }
        }
        guard shouldRun else {
            let wasMonitoring = monitoringActive || eventSource.isRunning
            if eventSource.isRunning {
                eventSource.stop()
            }
            monitoringActive = false
            if wasMonitoring {
                recordActivity(
                    level: .info,
                    category: .listener,
                    message: "窗口手势监听已停止"
                )
            }
            return
        }

        do {
            let wasRunning = eventSource.isRunning
            if !eventSource.isRunning {
                try eventSource.start()
            }
            monitoringActive = eventSource.isRunning
            if !wasRunning, monitoringActive {
                lastListenerErrorMessage = nil
                recordActivity(
                    level: .info,
                    category: .listener,
                    message: "窗口手势监听已启动"
                )
            }
        } catch {
            monitoringActive = false
            recordListenerErrorIfNeeded(error.localizedDescription)
        }
    }

    private func handleEventSourceFailure(_ error: EventSourceError) {
        gestureCoordinator.cancelCurrentSession()
        eventSource.stop()
        monitoringActive = false
        if error == .accessibilityPermissionRequired {
            accessibilityGranted = false
        }
        recordListenerErrorIfNeeded(error.localizedDescription)
        reconcileMonitoring()
    }

    private func recordListenerErrorIfNeeded(_ message: String) {
        guard message != lastListenerErrorMessage else { return }
        lastListenerErrorMessage = message
        recordActivity(level: .error, category: .listener, message: message)
    }

    private func presentOnboardingIfNeeded() {
        guard !defaults.bool(forKey: PreferenceKey.hasShownOnboarding) else { return }
        defaults.set(true, forKey: PreferenceKey.hasShownOnboarding)

        let rootView = PermissionOnboardingView(controller: self)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 496, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "欢迎使用 Ordo"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        onboardingWindow = window
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private static func loadChord(
        key: String,
        fallback: ModifierChord,
        defaults: UserDefaults
    ) -> ModifierChord {
        guard defaults.object(forKey: key) != nil else { return fallback }
        let chord = ModifierChord(rawValue: UInt8(clamping: defaults.integer(forKey: key)))
        return chord.isValid ? chord : fallback
    }

    private static func validationMessage(
        resize: ModifierChord,
        snap: ModifierChord,
        move: ModifierChord
    ) -> String? {
        do {
            try ModifierChord.validateUnique([resize, snap, move])
            return nil
        } catch let error as ModifierChordValidationError {
            switch error {
            case .tooFewModifiers:
                return "每组快捷键至少需要两个修饰键"
            case .unsupportedModifiers:
                return "快捷键只能使用 Command、Option、Control 和 Shift"
            case .duplicateChord:
                return "三组快捷键不能重复"
            }
        } catch {
            return "快捷键设置无效"
        }
    }
}
