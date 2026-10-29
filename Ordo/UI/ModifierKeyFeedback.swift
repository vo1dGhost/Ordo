import AppKit
import SwiftUI

/// 仅保存功能页的瞬时修饰键状态，不持久化、不写日志。
struct ModifierKeyFeedback: Equatable {
    private(set) var pressedModifiers: ModifierChord = []

    mutating func update(_ flags: NSEvent.ModifierFlags, isActive: Bool) {
        guard isActive else { clear(); return }
        var pressed: ModifierChord = []
        if flags.contains(.shift) { pressed.insert(.shift) }
        if flags.contains(.control) { pressed.insert(.control) }
        if flags.contains(.option) { pressed.insert(.option) }
        if flags.contains(.command) { pressed.insert(.command) }
        pressedModifiers = pressed
    }

    mutating func clear() { pressedModifiers = [] }
}

enum ModifierKeyDisplayState {
    case idle, selected, pressed

    init(key: ModifierChord, selection: ModifierChord, pressed: ModifierChord) {
        self = pressed.contains(key) ? .pressed : selection.contains(key) ? .selected : .idle
    }

    var tint: Color {
        switch self {
        case .idle: .gray
        case .selected: .blue
        case .pressed: .green
        }
    }
}

/// 使用窗口内只读 flagsChanged 观察，兼容 macOS 14，不启动全局监听或申请权限。
struct ModifierKeyFeedbackObserver: ViewModifier {
    @Binding var feedback: ModifierKeyFeedback
    @Environment(\.controlActiveState) private var activeState
    @State private var monitor: Any?
    @State private var isWindowKey = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                refresh()
                monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                    MainActor.assumeIsolated {
                        feedback.update(event.modifierFlags, isActive: isWindowKey && NSApp.isActive && NSApp.keyWindow != nil)
                    }
                    // 不吞掉或修改事件，系统和原有手势继续正常处理。
                    return event
                }
            }
            .onChange(of: activeState) { _, _ in refresh() }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
                isWindowKey = false
                feedback.clear()
            }
    }

    private func refresh() {
        isWindowKey = activeState == .key
        feedback.update(NSEvent.modifierFlags, isActive: isWindowKey && NSApp.isActive && NSApp.keyWindow != nil)
    }
}
