import AppKit
import XCTest
@testable import Ordo

@MainActor
final class AppLaunchTests: XCTestCase {
    func testManualLaunchRequestsMainWindowOnlyOnce() {
        let delegate = OrdoAppDelegate(shouldPresentOnManualLaunch: { true })
        delegate.handleLaunchEvent(nil)
        delegate.handleLaunchEvent(nil)
        XCTAssertEqual(delegate.mainWindowRequest, 1)
    }

    func testBackgroundLoginAndServiceLaunchDoNotRequestWindow() {
        for source in [keyAELaunchedAsLogInItem, keyAELaunchedAsServiceItem] {
            let delegate = OrdoAppDelegate(shouldPresentOnManualLaunch: { true })
            delegate.handleLaunchEvent(launchEvent(source: source))
            XCTAssertEqual(delegate.mainWindowRequest, 0)
            XCTAssertFalse(delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))
            XCTAssertEqual(delegate.mainWindowRequest, 1)
        }
    }

    func testReopenRequestsSameMainWindowRegardlessOfExistingVisibility() {
        let delegate = OrdoAppDelegate(shouldPresentOnManualLaunch: { true })
        delegate.handleLaunchEvent(nil)
        for visible in [false, true, false] {
            XCTAssertFalse(delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: visible))
        }
        XCTAssertEqual(delegate.mainWindowRequest, 4)
        XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    }

    func testEarlyReopenIsNotDuplicatedByLaunchNotification() {
        let delegate = OrdoAppDelegate(shouldPresentOnManualLaunch: { true })
        _ = delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        XCTAssertEqual(delegate.mainWindowRequest, 0)
        delegate.handleLaunchEvent(nil)
        XCTAssertEqual(delegate.mainWindowRequest, 1)
    }

    func testSilentManualLaunchIgnoresEarlyReopenButLaterReopenShowsWindow() {
        let delegate = OrdoAppDelegate(shouldPresentOnManualLaunch: { false })
        _ = delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        delegate.handleLaunchEvent(nil)
        delegate.handleLaunchEvent(nil)
        XCTAssertEqual(delegate.mainWindowRequest, 0)
        _ = delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        XCTAssertEqual(delegate.mainWindowRequest, 1)
        _ = delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true)
        XCTAssertEqual(delegate.mainWindowRequest, 2)
    }

    func testEarlyReopenDoesNotExposeLoginOrServiceLaunch() {
        for source in [keyAELaunchedAsLogInItem, keyAELaunchedAsServiceItem] {
            let delegate = OrdoAppDelegate(shouldPresentOnManualLaunch: { true })
            _ = delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
            delegate.handleLaunchEvent(launchEvent(source: source))
            XCTAssertEqual(delegate.mainWindowRequest, 0)
        }
    }

    private func launchEvent(source: AEKeyword) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEOpenApplication),
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        event.setParam(NSAppleEventDescriptor(enumCode: source), forKeyword: AEKeyword(keyAEPropData))
        return event
    }
}
