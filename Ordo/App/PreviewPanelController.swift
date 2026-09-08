import AppKit
import QuartzCore
import SwiftUI

@MainActor
protocol PreviewDisplaying: AnyObject {
    func show(layout: SnapLayout, targetFrame: CGRect, screen: ScreenGeometry)
    func showOriginMarker(at location: CGPoint, screen: ScreenGeometry)
    func hideLayout()
    func hide()
    func invalidate()
}

extension PreviewDisplaying {
    func invalidate() {
        hide()
    }
}

/// 在目标屏幕上显示不抢焦点、不接收输入的排布预览和手势起点标记。
@MainActor
final class PreviewPanelController: PreviewDisplaying {
    static let presentationAnimationKey = "ordo.preview.opacity"

    private static let markerSize = CGSize(
        width: SnapOriginMarkerView.size,
        height: SnapOriginMarkerView.size
    )
    private static let layoutLevel = NSWindow.Level(
        rawValue: NSWindow.Level.floating.rawValue + 1
    )
    private static let markerLevel = NSWindow.Level(
        rawValue: NSWindow.Level.floating.rawValue + 2
    )

    private var panel: NSPanel?
    private var markerPanel: NSPanel?
    private var currentLayout: SnapLayout?
    private var isLayoutPresented = false
    private var isMarkerPresented = false

    private let panelFactory: @MainActor () -> NSPanel
    private let markerPanelFactory: @MainActor () -> NSPanel
    private let accessibilityReduceMotion: @MainActor () -> Bool

    init(
        panelFactory: @escaping @MainActor () -> NSPanel = PreviewPanelController.makePanel,
        markerPanelFactory: @escaping @MainActor () -> NSPanel = PreviewPanelController.makePanel,
        accessibilityReduceMotion: @escaping @MainActor () -> Bool = {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
    ) {
        self.panelFactory = panelFactory
        self.markerPanelFactory = markerPanelFactory
        self.accessibilityReduceMotion = accessibilityReduceMotion
    }

    func show(layout: SnapLayout, targetFrame: CGRect, screen: ScreenGeometry) {
        let panel = layoutPanel()
        let startsPresentation = currentLayout != layout
            || !isLayoutPresented
            || panel.contentViewController == nil
            || !panel.isVisible

        if startsPresentation {
            removeLayoutHost(from: panel)
            panel.contentViewController = makeLayoutHost(for: layout)
            currentLayout = layout
        }

        let appKitFrame = screen.appKitRect(fromAX: targetFrame)
        if panel.frame != appKitFrame {
            panel.setFrame(appKitFrame, display: true)
        }
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }

        if startsPresentation, !accessibilityReduceMotion() {
            panel.displayIfNeeded()
            animatePresentation(on: panel.contentViewController?.view)
        }
        isLayoutPresented = true
        updateOriginMarker(layout: layout)
    }

    func showOriginMarker(at location: CGPoint, screen: ScreenGeometry) {
        guard !isMarkerPresented else { return }

        let panel = originMarkerPanel()
        if panel.contentViewController == nil {
            panel.contentViewController = NSHostingController(
                rootView: SnapOriginMarkerView(selectedLayout: nil)
            )
        }

        let appKitLocation = screen.appKitPoint(fromAX: location)
        let frame = CGRect(
            x: appKitLocation.x - Self.markerSize.width / 2,
            y: appKitLocation.y - Self.markerSize.height / 2,
            width: Self.markerSize.width,
            height: Self.markerSize.height
        )
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        isMarkerPresented = true
    }

    func hideLayout() {
        updateOriginMarker(layout: nil)
        guard let panel else {
            currentLayout = nil
            isLayoutPresented = false
            return
        }

        let shouldOrderOut = isLayoutPresented || panel.isVisible
        removeLayoutHost(from: panel)
        if shouldOrderOut {
            panel.orderOut(nil)
        }
        isLayoutPresented = false
    }

    func hide() {
        hideLayout()
        hideOriginMarker()
    }

    /// 睡眠、会话切换或屏幕重连后不复用旧的 WindowServer/SwiftUI 展示宿主。
    func invalidate() {
        hideLayout()
        if let panel {
            panel.close()
            self.panel = nil
        }

        hideOriginMarker()
        if let markerPanel {
            markerPanel.contentViewController = nil
            markerPanel.close()
            self.markerPanel = nil
        }
    }

    private func layoutPanel() -> NSPanel {
        if let panel {
            return panel
        }

        let panel = panelFactory()
        configure(panel, level: Self.layoutLevel)
        self.panel = panel
        return panel
    }

    private func originMarkerPanel() -> NSPanel {
        if let markerPanel {
            return markerPanel
        }

        let panel = markerPanelFactory()
        configure(panel, level: Self.markerLevel)
        self.markerPanel = panel
        return panel
    }

    private func makeLayoutHost(for layout: SnapLayout) -> NSViewController {
        let hostingController = NSHostingController(rootView: SnapPreviewView(layout: layout))
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.opacity = 1
        return hostingController
    }

    private func animatePresentation(on view: NSView?) {
        guard let layer = view?.layer else { return }

        layer.removeAnimation(forKey: Self.presentationAnimationKey)
        layer.opacity = 1

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 0.14
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: Self.presentationAnimationKey)
    }

    private func removeLayoutHost(from panel: NSPanel) {
        panel.contentViewController?.view.layer?.removeAnimation(
            forKey: Self.presentationAnimationKey
        )
        panel.contentViewController = nil
        currentLayout = nil
    }

    private func hideOriginMarker() {
        guard isMarkerPresented else { return }
        markerPanel?.orderOut(nil)
        // 结束时释放宿主，避免尚未结束的高亮过渡带入下一次手势。
        markerPanel?.contentViewController = nil
        isMarkerPresented = false
    }

    private func updateOriginMarker(layout: SnapLayout?) {
        guard isMarkerPresented,
              let host = markerPanel?.contentViewController
                as? NSHostingController<SnapOriginMarkerView>,
              host.rootView.selectedLayout != layout
        else { return }

        host.rootView = SnapOriginMarkerView(selectedLayout: layout)
    }

    private static func makePanel() -> NSPanel {
        NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
    }

    private func configure(_ panel: NSPanel, level: NSWindow.Level) {
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.alphaValue = 1
        panel.animationBehavior = .none
        panel.level = level
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.setAccessibilityElement(false)
    }
}
