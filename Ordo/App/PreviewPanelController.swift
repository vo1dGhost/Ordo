import AppKit
import SwiftUI

@MainActor
protocol PreviewDisplaying: AnyObject {
    func show(layout: SnapLayout, targetFrame: CGRect, screen: ScreenGeometry)
    func hide()
}

/// 在目标屏幕上显示不抢焦点、不接收输入的排布预览。
@MainActor
final class PreviewPanelController: PreviewDisplaying {
    private var panel: NSPanel?
    private var currentLayout: SnapLayout?

    func show(layout: SnapLayout, targetFrame: CGRect, screen: ScreenGeometry) {
        let appKitFrame = screen.appKitRect(fromAX: targetFrame)
        let panel = panel ?? makePanel()
        if currentLayout != layout {
            panel.contentViewController = NSHostingController(rootView: SnapPreviewView(layout: layout))
            currentLayout = layout
        }
        if panel.frame != appKitFrame {
            panel.setFrame(appKitFrame, display: true)
        }
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.setAccessibilityElement(false)
        return panel
    }
}
