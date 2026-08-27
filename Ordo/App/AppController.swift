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
        static let hasShownOnboarding = "ordo.onboarding.shown"
    }

    static let shared = AppController()

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: PreferenceKey.enabled)
            if !isEnabled {
                gestureCoordinator.cancelCurrentSession()
            }
            reconcileMonitoring()
        }
    }

    @Published private(set) var accessibilityGranted = false
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
    @Published var statusMessage: String?
    @Published private(set) var monitoringActive = false

    var isOperational: Bool {
        isEnabled && accessibilityGranted && shortcutValidationMessage == nil && monitoringActive
    }

    private let defaults: UserDefaults
    private let windowController: any WindowControlling
    private let screenProvider: any ScreenGeometryProviding
    private let eventSource: any EventSource
    private let previewController: PreviewPanelController

    private lazy var gestureCoordinator = GestureCoordinator(
        windowController: windowController,
        screenProvider: screenProvider,
        previewController: previewController
    ) { [weak self] message in
        self?.statusMessage = message
    }

    private var eventTask: Task<Void, Never>?
    private var eventFailureTask: Task<Void, Never>?
    private var screenTask: Task<Void, Never>?
    private var permissionTimer: Timer?
    private var onboardingWindow: NSWindow?
    private var hasStarted = false

    init(
        defaults: UserDefaults = .standard,
        windowController: any WindowControlling = AXWindowController(),
        screenProvider: any ScreenGeometryProviding = ScreenGeometryProvider(),
        eventSource: any EventSource = InputEventTap(),
        previewController: PreviewPanelController = PreviewPanelController()
    ) {
        self.defaults = defaults
        self.windowController = windowController
        self.screenProvider = screenProvider
        self.eventSource = eventSource
        self.previewController = previewController

        if defaults.object(forKey: PreferenceKey.enabled) == nil {
            isEnabled = true
        } else {
            isEnabled = defaults.bool(forKey: PreferenceKey.enabled)
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
                    if self?.gestureCoordinator.cancelCurrentSession() == true {
                        self?.statusMessage = "屏幕配置已变化，当前手势已结束"
                    }
                }
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

    func shutdown() {
        eventTask?.cancel()
        eventTask = nil
        eventFailureTask?.cancel()
        eventFailureTask = nil
        screenTask?.cancel()
        screenTask = nil
        permissionTimer?.invalidate()
        permissionTimer = nil
        gestureCoordinator.cancelCurrentSession()
        eventSource.stop()
        monitoringActive = false
        Task { [windowController] in
            await windowController.releaseAll()
        }
    }

    func requestAccessibility() {
        _ = AXWindowController.isAccessibilityTrusted(prompt: true)
        statusMessage = "请在系统设置中允许 Ordo 使用辅助功能；授权后会自动开始运行"
        refreshPermissions()
    }

    func refreshPermissions() {
        let granted = AXWindowController.isAccessibilityTrusted()
        if accessibilityGranted != granted {
            accessibilityGranted = granted
            if !granted {
                gestureCoordinator.cancelCurrentSession()
                statusMessage = "辅助功能权限已撤销，窗口手势已停止"
            } else {
                statusMessage = "辅助功能权限已授权"
            }
        }
        reconcileMonitoring()
    }

    func clearStatus() {
        statusMessage = nil
    }

    func dismissOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    private func shortcutsDidChange() {
        shortcutValidationMessage = Self.validationMessage(
            resize: resizeChord,
            snap: snapChord,
            move: moveChord
        )

        guard shortcutValidationMessage == nil else {
            gestureCoordinator.cancelCurrentSession()
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
        let shouldRun = isEnabled && accessibilityGranted && shortcutValidationMessage == nil
        guard shouldRun else {
            if eventSource.isRunning {
                eventSource.stop()
            }
            monitoringActive = false
            return
        }

        do {
            if !eventSource.isRunning {
                try eventSource.start()
            }
            monitoringActive = eventSource.isRunning
        } catch {
            monitoringActive = false
            statusMessage = error.localizedDescription
        }
    }

    private func handleEventSourceFailure(_ error: EventSourceError) {
        gestureCoordinator.cancelCurrentSession()
        eventSource.stop()
        monitoringActive = false
        if error == .accessibilityPermissionRequired {
            accessibilityGranted = false
        }
        statusMessage = error.localizedDescription
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
