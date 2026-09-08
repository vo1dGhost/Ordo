import AppKit
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
@testable import Ordo

final class AXWindowCompatibilityTests: XCTestCase {
    func testSystemAXActorUsesMainExecutorEvenFromDetachedCaller() async {
        let controller = AXWindowController()

        let isMainThread = await Task.detached(priority: .userInitiated) {
            await controller.isExecutingOnMainThreadForTesting()
        }.value

        XCTAssertTrue(isMainThread)
    }

    @MainActor
    func testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized() async throws {
        guard AXWindowController.isAccessibilityTrusted() else {
            throw XCTSkip("测试宿主未获辅助功能权限")
        }
        guard let primaryScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) else {
            throw XCTSkip("没有可用主屏幕")
        }

        let visibleFrame = primaryScreen.visibleFrame
        let contentRect = CGRect(
            x: visibleFrame.midX - 180,
            y: visibleFrame.midY - 90,
            width: 360,
            height: 180
        )
        let model = SelfWindowProbeModel()
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ordo 自身窗口 AX 回归"
        window.contentView = NSHostingView(rootView: SelfWindowProbeView(model: model))
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        try await Task.sleep(for: .milliseconds(100))
        let appKitPoint = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let quartzPoint = ScreenCoordinateConverter.appKitToQuartz(
            appKitPoint,
            mainScreenFrame: primaryScreen.frame
        )
        let controller = AXWindowController()
        let captured = try await controller.captureWindow(at: quartzPoint, for: .move)

        XCTAssertEqual(captured.pid, ProcessInfo.processInfo.processIdentifier)
        try await controller.raiseWindow(captured)
        let moved = try await controller.setPosition(
            CGPoint(x: captured.frame.minX + 8, y: captured.frame.minY + 8),
            of: captured
        )
        _ = try await controller.setSize(
            CGSize(width: moved.frame.width + 8, height: moved.frame.height + 8),
            of: moved
        )
        await controller.release(captured)
    }

    func testWindowRaiseCompatibilityContinuesOnlyForBestEffortResults() {
        XCTAssertTrue(AXWindowRaiseCompatibility.shouldContinue(after: .success))
        XCTAssertTrue(AXWindowRaiseCompatibility.shouldContinue(after: .actionUnsupported))
        XCTAssertTrue(AXWindowRaiseCompatibility.shouldContinue(after: .notImplemented))
        XCTAssertTrue(AXWindowRaiseCompatibility.shouldContinue(after: .cannotComplete))

        XCTAssertFalse(AXWindowRaiseCompatibility.shouldContinue(after: .apiDisabled))
        XCTAssertFalse(AXWindowRaiseCompatibility.shouldContinue(after: .invalidUIElement))
        XCTAssertFalse(AXWindowRaiseCompatibility.shouldContinue(after: .illegalArgument))
        XCTAssertFalse(AXWindowRaiseCompatibility.shouldContinue(after: .failure))
    }

    func testAttributeUnsupportedFromRaisePreservesGeometryCompatibility() {
        // Ordo 自身的 SwiftUI 窗口在 AXRaise 时可能返回 -25205，而非 actionUnsupported。
        let result = AXError.attributeUnsupported

        XCTAssertEqual(result.rawValue, -25205)
        XCTAssertTrue(AXWindowRaiseCompatibility.shouldContinue(after: result))
    }

    func testEnhancedUserInterfaceCompatibilityRequiresSuccessfulStrictBooleanTrue() {
        XCTAssertTrue(
            AXEnhancedUserInterfaceCompatibility.isStrictlyEnabled(
                readResult: .success,
                value: kCFBooleanTrue
            )
        )
        XCTAssertFalse(
            AXEnhancedUserInterfaceCompatibility.isStrictlyEnabled(
                readResult: .success,
                value: kCFBooleanFalse
            )
        )
        XCTAssertFalse(
            AXEnhancedUserInterfaceCompatibility.isStrictlyEnabled(
                readResult: .noValue,
                value: kCFBooleanTrue
            )
        )
        XCTAssertFalse(
            AXEnhancedUserInterfaceCompatibility.isStrictlyEnabled(
                readResult: .success,
                value: "true" as CFString
            )
        )
    }

    func testEnhancedUserInterfaceCompatibilityDistinguishesStrictFalseFromUnavailable() {
        XCTAssertEqual(
            AXEnhancedUserInterfaceCompatibility.strictBooleanValue(
                readResult: .success,
                value: kCFBooleanFalse
            ),
            false
        )
        XCTAssertNil(
            AXEnhancedUserInterfaceCompatibility.strictBooleanValue(
                readResult: .noValue,
                value: kCFBooleanFalse
            )
        )
        XCTAssertNil(
            AXEnhancedUserInterfaceCompatibility.strictBooleanValue(
                readResult: .success,
                value: "false" as CFString
            )
        )
    }

    func testSuppressionRegistryKeepsApplicationSuppressedUntilLastOwnerLeaves() {
        var registry = AXEnhancedUserInterfaceSuppressionRegistry()
        let first = registry.addOwner(pid: 42, ownerID: UUID())
        let second = registry.addOwner(pid: 42, ownerID: UUID())

        XCTAssertTrue(registry.isTracking(pid: 42))
        XCTAssertTrue(registry.hasActiveOwners(pid: 42))
        XCTAssertFalse(registry.removeOwner(first))
        XCTAssertTrue(registry.removeOwner(second))
        XCTAssertTrue(registry.isTracking(pid: 42))
        XCTAssertFalse(registry.hasActiveOwners(pid: 42))
        XCTAssertTrue(registry.isAwaitingRestoration(pid: 42))

        registry.finishRestoration(pid: 42)
        XCTAssertFalse(registry.isTracking(pid: 42))
    }

    func testSuppressionRegistryIgnoresDuplicateRelease() {
        var registry = AXEnhancedUserInterfaceSuppressionRegistry()
        let lease = registry.addOwner(pid: 42, ownerID: UUID())

        XCTAssertTrue(registry.removeOwner(lease))
        XCTAssertFalse(registry.removeOwner(lease))
    }

    func testSuppressionRegistryReusesPendingRestorationForNewOwner() {
        var registry = AXEnhancedUserInterfaceSuppressionRegistry()
        let first = registry.addOwner(pid: 42, ownerID: UUID())
        XCTAssertTrue(registry.removeOwner(first))

        let second = registry.addOwner(pid: 42, ownerID: UUID())
        XCTAssertFalse(registry.removeOwner(first))
        XCTAssertTrue(registry.removeOwner(second))
    }

    func testSuppressionRegistryCanTrackAnUncertainDisableWriteWithoutAnOwner() {
        var registry = AXEnhancedUserInterfaceSuppressionRegistry()

        registry.markAwaitingRestoration(pid: 42)

        XCTAssertTrue(registry.isTracking(pid: 42))
        XCTAssertFalse(registry.hasActiveOwners(pid: 42))
        XCTAssertTrue(registry.isAwaitingRestoration(pid: 42))
    }

    func testSuppressionRegistryTracksApplicationsIndependently() {
        var registry = AXEnhancedUserInterfaceSuppressionRegistry()
        let firstApplication = registry.addOwner(pid: 41, ownerID: UUID())
        let secondApplication = registry.addOwner(pid: 42, ownerID: UUID())

        XCTAssertTrue(registry.removeOwner(firstApplication))
        registry.finishRestoration(pid: 41)

        XCTAssertFalse(registry.isTracking(pid: 41))
        XCTAssertTrue(registry.isTracking(pid: 42))
        XCTAssertTrue(registry.removeOwner(secondApplication))
    }

    func testSuppressionRegistryRemoveAllClearsActiveAndPendingApplications() {
        var registry = AXEnhancedUserInterfaceSuppressionRegistry()
        _ = registry.addOwner(pid: 41, ownerID: UUID())
        let pending = registry.addOwner(pid: 42, ownerID: UUID())
        XCTAssertTrue(registry.removeOwner(pending))

        XCTAssertEqual(Set(registry.trackedPIDs), Set([41, 42]))
        registry.removeAll()

        XCTAssertTrue(registry.trackedPIDs.isEmpty)
        XCTAssertFalse(registry.isTracking(pid: 41))
        XCTAssertFalse(registry.isTracking(pid: 42))
    }

    func testRestorationRetriesOnlyTransientAXErrors() {
        XCTAssertTrue(
            AXEnhancedUserInterfaceCompatibility.shouldRetryRestoration(after: .cannotComplete)
        )
        XCTAssertTrue(
            AXEnhancedUserInterfaceCompatibility.shouldRetryRestoration(after: .apiDisabled)
        )
        XCTAssertTrue(
            AXEnhancedUserInterfaceCompatibility.shouldRetryRestoration(after: .failure)
        )

        XCTAssertFalse(
            AXEnhancedUserInterfaceCompatibility.shouldRetryRestoration(after: .success)
        )
        XCTAssertFalse(
            AXEnhancedUserInterfaceCompatibility.shouldRetryRestoration(after: .illegalArgument)
        )
        XCTAssertFalse(
            AXEnhancedUserInterfaceCompatibility.shouldRetryRestoration(after: .attributeUnsupported)
        )
    }

    func testFrameVerificationPolicyAllowsTwoReadsOneFrameApart() {
        XCTAssertEqual(WindowFrameVerificationPolicy.maximumReadAttempts, 2)
        XCTAssertEqual(WindowFrameVerificationPolicy.retryDelay, .milliseconds(17))
    }

    func testFrameVerificationChecksPositionAndSizeWithTwoPointTolerance() {
        let target = CGRect(x: -500, y: 20, width: 500, height: 400)

        XCTAssertTrue(WindowFrameVerificationPolicy.matches(target, target))
        XCTAssertTrue(
            WindowFrameVerificationPolicy.matches(
                CGRect(x: -498, y: 18, width: 502, height: 398),
                target
            )
        )
        XCTAssertFalse(
            WindowFrameVerificationPolicy.matches(
                CGRect(x: -497, y: 20, width: 500, height: 400),
                target
            )
        )
        XCTAssertFalse(
            WindowFrameVerificationPolicy.matches(
                CGRect(x: -500, y: 20, width: 503, height: 400),
                target
            )
        )
    }

    func testFrameVerificationClassifiesPositionAndSizeSeparately() {
        let target = CGRect(x: 100, y: 100, width: 500, height: 400)

        XCTAssertEqual(
            WindowFrameVerificationPolicy.mismatch(
                CGRect(x: 110, y: 100, width: 500, height: 400),
                target
            ),
            .position
        )
        XCTAssertEqual(
            WindowFrameVerificationPolicy.mismatch(
                CGRect(x: 100, y: 100, width: 510, height: 400),
                target
            ),
            .size
        )
        XCTAssertEqual(
            WindowFrameVerificationPolicy.mismatch(
                CGRect(x: 110, y: 100, width: 510, height: 400),
                target
            ),
            [.position, .size]
        )
    }

    func testRejectedFrameErrorDescribesTheMismatchedComponents() {
        XCTAssertEqual(
            AXWindowControllerError.targetFrameRejected(.position).localizedDescription,
            "目标应用未接受排布位置"
        )
        XCTAssertEqual(
            AXWindowControllerError.targetFrameRejected(.size).localizedDescription,
            "目标应用未接受排布尺寸"
        )
        XCTAssertEqual(
            AXWindowControllerError.targetFrameRejected([.position, .size]).localizedDescription,
            "目标应用未接受排布位置或尺寸"
        )
    }
}

private extension AXWindowController {
    func isExecutingOnMainThreadForTesting() -> Bool {
        Thread.isMainThread
    }
}

@MainActor
private final class SelfWindowProbeModel: ObservableObject {
    @Published var value = 2.0
}

private struct SelfWindowProbeView: View {
    @ObservedObject var model: SelfWindowProbeModel

    var body: some View {
        Slider(
            value: Binding(
                get: { model.value },
                set: { model.value = $0 }
            ),
            in: 0...4,
            step: 1
        )
        .padding(40)
    }
}
