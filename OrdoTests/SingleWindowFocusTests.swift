import ApplicationServices
import XCTest
@testable import Ordo

final class SingleWindowFocusTests: XCTestCase {
    func testActivationRequiresConfirmedTargetAndReadsFocusBackAfterward() async throws {
        let probe = FocusSequenceProbe()

        let confirmed = try await probe.run()
        let steps = await probe.steps

        XCTAssertTrue(confirmed)
        XCTAssertEqual(steps, [.raise, .prepareMain, .prepareFocus, .confirmTarget, .activate, .confirmFocus])
        XCTAssertEqual(steps.filter { $0 == .activate }.count, 1)
    }

    func testSoftRaiseOrPreparationFailureNeverActivatesTheApplication() async throws {
        for step in [SingleWindowFocusStep.raise, .prepareMain, .prepareFocus, .confirmTarget] {
            let probe = FocusSequenceProbe(softFailureAt: step)

            let confirmed = try await probe.run()
            let steps = await probe.steps

            XCTAssertFalse(confirmed)
            XCTAssertFalse(steps.contains(.activate))
            XCTAssertFalse(steps.contains(.confirmFocus))
        }
    }

    func testActivationReturnCodeDoesNotProveFocusWasTransferred() async throws {
        let probe = FocusSequenceProbe(softFailureAt: .confirmFocus)

        let confirmed = try await probe.run()
        let steps = await probe.steps

        XCTAssertFalse(confirmed)
        XCTAssertEqual(steps.filter { $0 == .activate }.count, 1)
        XCTAssertEqual(steps.last, .confirmFocus)
    }

    func testFailedActivationIsNotRetried() async throws {
        let probe = FocusSequenceProbe(softFailureAt: .activate)

        let confirmed = try await probe.run()
        let steps = await probe.steps

        XCTAssertFalse(confirmed)
        XCTAssertEqual(steps.filter { $0 == .activate }.count, 1)
        XCTAssertFalse(steps.contains(.confirmFocus))
    }

    func testPermissionRevocationBetweenPreparationAndActivationStopsAllLaterSteps() async {
        let probe = FocusSequenceProbe(hardFailureAt: .activate)

        do {
            _ = try await probe.run()
            XCTFail("撤权后不应继续置前流程")
        } catch {
            XCTAssertEqual(error as? AXWindowControllerError, .accessibilityPermissionRequired)
        }
        let steps = await probe.steps
        XCTAssertFalse(steps.contains(.activate))
        XCTAssertFalse(steps.contains(.confirmFocus))
    }

    func testWindowInvalidationAfterActivationStillTerminatesTheRequest() async {
        let failure = AXWindowControllerError.windowNoLongerAvailable(UUID())
        let probe = FocusSequenceProbe(hardFailureAt: .confirmFocus, hardFailure: failure)

        do {
            _ = try await probe.run()
            XCTFail("失效窗口不能继续用于几何写入")
        } catch {
            XCTAssertEqual(error as? AXWindowControllerError, failure)
        }
        let steps = await probe.steps
        XCTAssertEqual(steps.last, .activate)
    }

    func testCancellationAtAnyStepPreventsLaterSideEffects() async {
        for step in SingleWindowFocusStep.allCases {
            let probe = FocusSequenceProbe(cancelAfter: step)
            let task = Task { try await probe.run() }

            do {
                _ = try await task.value
                XCTFail("取消必须终止置前流程")
            } catch {
                XCTAssertTrue(error is CancellationError)
            }
            let steps = await probe.steps
            XCTAssertEqual(steps.last, step)
        }
    }

    func testAlreadyCancelledRequestDoesNotRaiseOrActivate() async {
        let probe = FocusSequenceProbe()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await probe.run()
        }

        do {
            _ = try await task.value
            XCTFail("取消后不应发起 AXRaise")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        let steps = await probe.steps
        XCTAssertTrue(steps.isEmpty)
    }

    func testFocusCompatibilityOnlySkipsUnsupportedOrUnavailableAttributes() {
        for error in [AXError.attributeUnsupported, .noValue, .notImplemented, .cannotComplete, .actionUnsupported] {
            XCTAssertTrue(AXWindowFocusCompatibility.isSoftFailure(error))
        }
        for error in [AXError.apiDisabled, .invalidUIElement, .illegalArgument, .failure, .success] {
            XCTAssertFalse(AXWindowFocusCompatibility.isSoftFailure(error))
        }
    }

    func testProcessActivationOptionsRestrictBringingForwardToOneWindow() {
        XCTAssertEqual(
            SingleWindowProcessActivator.options,
            OptionBits(kSetFrontProcessFrontWindowOnly | kSetFrontProcessCausedByUser)
        )
    }

    func testProductionTargetGateActivatesOnlyAfterMatchingMainFocusedAndMainAgain() async throws {
        let probe = FocusTargetGateProbe()

        let activated = try await probe.activate()
        let reads = await probe.reads
        let calls = await probe.activationCount

        XCTAssertTrue(activated)
        XCTAssertEqual(reads, [.main, .focused, .main])
        XCTAssertEqual(calls, 1)
    }

    func testProductionTargetGateRejectsWrongMainFocusedOrChangedMainWindow() async throws {
        // 第三次身份读取模拟 focused 读取后远端主窗已被用户换走。
        for mismatchAt in 1...3 {
            let probe = FocusTargetGateProbe(mismatchAtRead: mismatchAt)

            let activated = try await probe.activate()
            let calls = await probe.activationCount

            XCTAssertFalse(activated)
            XCTAssertEqual(calls, 0)
        }
    }

    func testProductionTargetGateRejectsPermissionLossIncludingImmediatelyBeforeActivation() async {
        for validationIndex in 1...4 {
            let probe = FocusTargetGateProbe(permissionFailureAtValidation: validationIndex)

            do {
                _ = try await probe.activate()
                XCTFail("权限撤销后不能调用进程激活")
            } catch {
                XCTAssertEqual(error as? AXWindowControllerError, .accessibilityPermissionRequired)
            }
            let calls = await probe.activationCount
            XCTAssertEqual(calls, 0)
        }
    }

    func testProductionTargetGatePropagatesWindowInvalidationInsteadOfActivatingAnotherWindow() async {
        let probe = FocusTargetGateProbe(invalidWindowAtRead: 2)

        do {
            _ = try await probe.activate()
            XCTFail("失效窗口不能激活进程当前的其他窗口")
        } catch {
            guard let controllerError = error as? AXWindowControllerError,
                  case .windowNoLongerAvailable = controllerError else {
                return XCTFail("应保留窗口失效错误：\(error)")
            }
        }
        let calls = await probe.activationCount
        XCTAssertEqual(calls, 0)
    }

    func testProductionTargetGateHonorsCancellationAfterEachIdentityRead() async {
        for readIndex in 1...3 {
            let probe = FocusTargetGateProbe(cancelAfterRead: readIndex)
            let task = Task { try await probe.activate() }

            do {
                _ = try await task.value
                XCTFail("读回期间取消后不能激活")
            } catch {
                XCTAssertTrue(error is CancellationError)
            }
            let calls = await probe.activationCount
            XCTAssertEqual(calls, 0)
        }
    }

    func testProductionTargetGateDoesNotRetryFailedProcessActivation() async throws {
        let probe = FocusTargetGateProbe(activationResult: -50)

        let activated = try await probe.activate()
        let calls = await probe.activationCount

        XCTAssertFalse(activated)
        XCTAssertEqual(calls, 1)
    }
}

private actor FocusTargetGateProbe {
    private(set) var reads: [SingleWindowFocusIdentity] = []
    private(set) var activationCount = 0
    private var validationCount = 0
    let mismatchAtRead: Int?
    let permissionFailureAtValidation: Int?
    let invalidWindowAtRead: Int?
    let cancelAfterRead: Int?
    let activationResult: OSStatus

    init(
        mismatchAtRead: Int? = nil,
        permissionFailureAtValidation: Int? = nil,
        invalidWindowAtRead: Int? = nil,
        cancelAfterRead: Int? = nil,
        activationResult: OSStatus = noErr
    ) {
        self.mismatchAtRead = mismatchAtRead
        self.permissionFailureAtValidation = permissionFailureAtValidation
        self.invalidWindowAtRead = invalidWindowAtRead
        self.cancelAfterRead = cancelAfterRead
        self.activationResult = activationResult
    }

    func activate() throws -> Bool {
        try SingleWindowFocusTargetGate.activateIfConfirmed(
            on: self,
            validate: { probe in try probe.validate() },
            matches: { probe, identity in try probe.matches(identity) },
            activate: { probe in
                probe.activationCount += 1
                return probe.activationResult
            }
        )
    }

    private func validate() throws {
        validationCount += 1
        if permissionFailureAtValidation == validationCount {
            throw AXWindowControllerError.accessibilityPermissionRequired
        }
    }

    private func matches(_ identity: SingleWindowFocusIdentity) throws -> Bool {
        reads.append(identity)
        if invalidWindowAtRead == reads.count {
            throw AXWindowControllerError.windowNoLongerAvailable(UUID())
        }
        if cancelAfterRead == reads.count {
            withUnsafeCurrentTask { $0?.cancel() }
        }
        return mismatchAtRead != reads.count
    }
}

private actor FocusSequenceProbe {
    private(set) var steps: [SingleWindowFocusStep] = []
    let softFailureAt: SingleWindowFocusStep?
    let hardFailureAt: SingleWindowFocusStep?
    let hardFailure: AXWindowControllerError
    let cancelAfter: SingleWindowFocusStep?

    init(
        softFailureAt: SingleWindowFocusStep? = nil,
        hardFailureAt: SingleWindowFocusStep? = nil,
        hardFailure: AXWindowControllerError = .accessibilityPermissionRequired,
        cancelAfter: SingleWindowFocusStep? = nil
    ) {
        self.softFailureAt = softFailureAt
        self.hardFailureAt = hardFailureAt
        self.hardFailure = hardFailure
        self.cancelAfter = cancelAfter
    }

    func run() async throws -> Bool {
        try await SingleWindowFocusSequence.run(on: self) { probe, step in
            try probe.perform(step)
        }
    }

    private func perform(_ step: SingleWindowFocusStep) throws -> Bool {
        // 每步的验证先于副作用；用撤权替身确认异常不会变成整 App 激活。
        if hardFailureAt == step {
            throw hardFailure
        }
        steps.append(step)
        if cancelAfter == step {
            withUnsafeCurrentTask { $0?.cancel() }
        }
        return softFailureAt != step
    }
}
