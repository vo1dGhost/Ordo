import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var controller: AppController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            controller.markMainWindowPresented()
            MainWindowPresentation.open(using: openWindow)
        } label: {
            Label("打开", systemImage: "macwindow")
                .labelStyle(.titleAndIcon)
        }
        .accessibilityLabel("打开")
        .accessibilityHint("打开 Ordo 主界面")

        Divider()

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("退出", systemImage: "power")
                .labelStyle(.titleAndIcon)
        }
        .accessibilityLabel("退出")
    }
}
