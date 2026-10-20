import CoreGraphics
import Foundation

/// 把全局输入、纯手势模型与 AX 窗口写入串联起来。
@MainActor
final class GestureCoordinator {
    private struct MotionRequest: Sendable {
        let mode: InteractionMode
        let window: WindowSnapshot
        let frame: CGRect
    }

    private enum WindowRaiseResult: Sendable {
        case succeeded
        case cancelled
        case failed(String)
    }

    private struct TerminalTask {
        let raiseToken: UInt64
        let task: Task<Void, Never>
    }

    private let windowController: any WindowControlling
    private let screenProvider: any ScreenGeometryProviding
    private let previewController: any PreviewDisplaying
    private let onStatus: @MainActor (String) -> Void
    private let snapTransition: @MainActor () -> WindowFrameTransition
    private let onOutcome: @MainActor (GestureOutcome) -> Void

    private var resizeChord = ModifierChord.defaultResize
    private var snapChord = ModifierChord.defaultSnap
    private var moveChord = ModifierChord.defaultMove

    private var session: GestureSession?
    private var activeChord: ModifierChord?
    private var lockedScreen: ScreenGeometry?
    private var radialClassifier = RadialGestureClassifier()
    private var pendingMotion: MotionRequest?
    private var motionTask: Task<Void, Never>?
    private var captureTask: Task<Void, Never>?
    private var pendingCaptureMouseLocations: [CGPoint] = []
    private var pendingCaptureOrigin: CGPoint?
    private var pendingCaptureHasActivated = false
    private var pendingFinishAfterCapture: ModifierChord?
    private var raiseTasks: [UInt64: Task<WindowRaiseResult, Never>] = [:]
    private var terminalTasks: [UInt64: TerminalTask] = [:]
    private var generation: UInt64 = 0
    private var requiresFullModifierRelease = false
    private var currentModifiers: ModifierChord = []

    init(
        windowController: any WindowControlling,
        screenProvider: any ScreenGeometryProviding,
        previewController: any PreviewDisplaying,
        onStatus: @escaping @MainActor (String) -> Void,
        snapTransition: @escaping @MainActor () -> WindowFrameTransition = {
            .animated(.snapDefault)
        },
        onOutcome: @escaping @MainActor (GestureOutcome) -> Void = { _ in }
    ) {
        self.windowController = windowController
        self.screenProvider = screenProvider
        self.previewController = previewController
        self.onStatus = onStatus
        self.snapTransition = snapTransition
        self.onOutcome = onOutcome
    }

    func updateShortcuts(resize: ModifierChord, snap: ModifierChord, move: ModifierChord) {
        resizeChord = resize
        snapChord = snap
        moveChord = move
    }

    func handle(_ event: InputEvent) {
        switch event.kind {
        case .flagsChanged:
            handleModifierChange(event)
        case .mouseMoved:
            handleMouseEvent(event)
        case .inputOverflow:
            currentModifiers = event.modifiers
            cancelCurrentSession()
            requiresFullModifierRelease = !event.modifiers.isEmpty
        }
    }

    /// 权限撤销、暂停或屏幕参数变化都会终止当前会话，且不提交排布。
    @discardableResult
    func cancelCurrentSession() -> Bool {
        let hadActiveChord = activeChord != nil
        let hadActiveWork = hadActiveChord
            || session != nil
            || !raiseTasks.isEmpty
            || !terminalTasks.isEmpty
        generation &+= 1
        captureTask?.cancel()
        captureTask = nil
        clearPendingCaptureInput()
        motionTask?.cancel()
        motionTask = nil
        for task in raiseTasks.values {
            task.cancel()
        }
        raiseTasks.removeAll()
        for terminalTask in terminalTasks.values {
            terminalTask.task.cancel()
        }
        terminalTasks.removeAll()
        pendingMotion = nil
        previewController.hide()
        radialClassifier.reset()

        if var session {
            session.cancel()
            let window = session.window
            Task { [windowController] in
                await windowController.release(window)
            }
        }

        session = nil
        lockedScreen = nil
        activeChord = nil
        requiresFullModifierRelease = requiresFullModifierRelease
            || (hadActiveChord && !currentModifiers.isEmpty)
        return hadActiveWork
    }

    /// 监听中断期间可能丢失松键边界，必须先观察到全部松开才能开始新手势。
    func handleInputInterruption() {
        cancelCurrentSession()
        requiresFullModifierRelease = true
    }

    private func clearPendingCaptureInput() {
        pendingCaptureMouseLocations.removeAll(keepingCapacity: true)
        pendingCaptureOrigin = nil
        pendingCaptureHasActivated = false
        pendingFinishAfterCapture = nil
    }

    private var canReplaceTrackingSession: Bool {
        session?.phase != .active && !pendingCaptureHasActivated && pendingFinishAfterCapture == nil
    }

    /// 捕获期间已松键的手势仍可提交；若完整松键后又开始新手势，则取消旧捕获。
    private func handleReleasedPendingCapture(_ event: InputEvent) -> Bool {
        guard captureTask != nil, session == nil, let remainingModifiers = pendingFinishAfterCapture else {
            return false
        }
        if event.modifiers.isEmpty {
            pendingFinishAfterCapture = []
        } else if remainingModifiers.isEmpty, let mode = mode(matching: event.modifiers) {
            replaceSession(with: mode, chord: event.modifiers, location: event.location)
        }
        return true
    }

    private func handleModifierChange(_ event: InputEvent) {
        currentModifiers = event.modifiers
        if requiresFullModifierRelease {
            if event.modifiers.isEmpty {
                requiresFullModifierRelease = false
            }
            return
        }

        if handleReleasedPendingCapture(event) { return }

        if let activeChord {
            if event.modifiers != activeChord,
               event.modifiers.contains(activeChord),
               let replacementMode = mode(matching: event.modifiers),
               canReplaceTrackingSession {
                replaceSession(
                    with: replacementMode,
                    chord: event.modifiers,
                    location: event.location
                )
                return
            }

            // 手势进入 active 状态后忽略额外修饰键；任一必要修饰键松开即提交。
            if !event.modifiers.contains(activeChord) {
                if captureTask != nil, session == nil {
                    // AX 命中尚未返回时先记住松键；捕获完成后仍提交这次快速手势。
                    pendingFinishAfterCapture = event.modifiers
                } else {
                    finishCurrentSession(remainingModifiers: event.modifiers)
                }
            }
            return
        }

        guard let mode = mode(matching: event.modifiers) else {
            return
        }
        beginSession(mode: mode, chord: event.modifiers, location: event.location)
    }

    private func beginSession(mode: InteractionMode, chord: ModifierChord, location: CGPoint) {
        cancelPendingTerminalTasks()
        generation &+= 1
        let token = generation
        activeChord = chord
        clearPendingCaptureInput()
        pendingCaptureOrigin = location
        // 每轮在异步捕获前重置；进入距离固定为 8 pt，清除距离为其三分之二。
        radialClassifier = RadialGestureClassifier()

        let screen = mode == .snap ? screenProvider.screen(containingAXPoint: location) : nil
        if mode == .snap, screen == nil {
            activeChord = nil
            requiresFullModifierRelease = true
            previewController.hide()
            onStatus("无法确定鼠标所在屏幕")
            return
        }
        lockedScreen = screen

        captureTask = Task { [weak self, windowController] in
            do {
                try Task.checkCancellation()
                let window = try await windowController.captureWindow(at: location, for: mode)
                guard let self else {
                    await windowController.release(window)
                    return
                }
                guard !Task.isCancelled,
                      self.generation == token,
                      self.activeChord == chord
                else {
                    await windowController.release(window)
                    return
                }

                self.session = GestureSession(
                    mode: mode,
                    window: window,
                    startMouseLocation: location,
                    lockedVisibleFrame: screen?.visibleFrame,
                    activationThreshold: GestureSession.defaultActivationThreshold
                )
                self.captureTask = nil
                self.pendingCaptureOrigin = nil
                self.pendingCaptureHasActivated = false

                if mode == .snap,
                   let screen,
                   self.pendingFinishAfterCapture == nil,
                   self.currentModifiers.contains(chord) {
                    self.previewController.showOriginMarker(at: location, screen: screen)
                }

                let pendingLocations = self.pendingCaptureMouseLocations
                self.pendingCaptureMouseLocations.removeAll(keepingCapacity: true)
                for pendingLocation in pendingLocations {
                    self.processMouseMove(pendingLocation)
                }
                if let remainingModifiers = self.pendingFinishAfterCapture {
                    self.pendingFinishAfterCapture = nil
                    self.finishCurrentSession(remainingModifiers: remainingModifiers)
                }
            } catch {
                guard let self, self.generation == token else { return }
                self.captureTask = nil
                // 已完整松键后的当前按键属于下一轮，捕获失败也不能丢掉这个边界。
                let hasFullyReleased = self.pendingFinishAfterCapture?.isEmpty == true
                self.clearPendingCaptureInput()
                self.activeChord = nil
                self.lockedScreen = nil
                self.requiresFullModifierRelease = !hasFullyReleased && !self.currentModifiers.isEmpty
                self.radialClassifier.reset()
                self.previewController.hide()
                self.onStatus(error.localizedDescription)
            }
        }
    }

    private func handleMouseEvent(_ event: InputEvent) {
        currentModifiers = event.modifiers
        if requiresFullModifierRelease {
            if event.modifiers.isEmpty {
                requiresFullModifierRelease = false
            }
            return
        }

        if handleReleasedPendingCapture(event) { return }

        if let activeChord {
            if event.modifiers != activeChord,
               event.modifiers.contains(activeChord),
               let replacementMode = mode(matching: event.modifiers),
               canReplaceTrackingSession {
                replaceSession(
                    with: replacementMode,
                    chord: event.modifiers,
                    location: event.location
                )
                return
            }

            // AsyncStream 极端拥塞时 flagsChanged 也可能被淘汰；鼠标事件的 flags 是安全兜底。
            if !event.modifiers.contains(activeChord) {
                if captureTask != nil, session == nil {
                    pendingFinishAfterCapture = event.modifiers
                } else {
                    finishCurrentSession(remainingModifiers: event.modifiers)
                }
                return
            }
        }

        processMouseMove(event.location)
    }

    private func processMouseMove(_ location: CGPoint) {
        if session == nil,
           captureTask != nil,
           activeChord != nil,
           pendingFinishAfterCapture == nil {
            // 径向选择带迟滞，必须按顺序重放路径，不能只保留最后一点。
            pendingCaptureMouseLocations.append(location)
            if let origin = pendingCaptureOrigin,
               hypot(location.x - origin.x, location.y - origin.y) > GestureSession.defaultActivationThreshold {
                // 越界后保持锁定，指针返回死区也不能被较长组合键替换。
                pendingCaptureHasActivated = true
            }
            return
        }

        guard var session, !session.isEnded else {
            return
        }

        let becameActive = session.updateMouseLocation(location)

        switch session.mode {
        case .snap:
            let selectedLayout = radialClassifier.update(
                from: session.startMouseLocation,
                to: location
            )
            session.setSelectedLayout(selectedLayout)
            self.session = session

            if becameActive {
                startRaiseIfNeeded(session.window, mode: session.mode, token: generation)
            }
            if pendingFinishAfterCapture == nil,
               let selectedLayout,
               let screen = lockedScreen,
               let visibleFrame = session.lockedVisibleFrame
            {
                previewController.show(
                    layout: selectedLayout,
                    targetFrame: LayoutEngine.targetFrame(for: selectedLayout, in: visibleFrame),
                    screen: screen
                )
            } else {
                previewController.hideLayout()
            }

        case .move, .resize:
            self.session = session
            guard session.phase == .active else {
                return
            }
            if becameActive {
                startRaiseIfNeeded(session.window, mode: session.mode, token: generation)
            }
            let frame: CGRect
            switch session.mode {
            case .move:
                frame = WindowFrameCalculator.movedFrame(
                    initialFrame: session.window.frame,
                    from: session.startMouseLocation,
                    to: location
                )
            case .resize:
                frame = WindowFrameCalculator.resizedFrame(
                    initialFrame: session.window.frame,
                    from: session.startMouseLocation,
                    to: location
                )
            case .snap:
                return
            }
            pendingMotion = MotionRequest(mode: session.mode, window: session.window, frame: frame)
            drainPendingMotionIfNeeded()
        }
    }

    private func finishCurrentSession(remainingModifiers: ModifierChord) {
        let sessionToken = generation
        generation &+= 1
        let terminalToken = generation
        captureTask?.cancel()
        captureTask = nil
        clearPendingCaptureInput()
        motionTask?.cancel()
        motionTask = nil
        pendingMotion = nil
        previewController.hide()
        radialClassifier.reset()
        activeChord = nil
        requiresFullModifierRelease = !remainingModifiers.isEmpty

        guard var session else {
            lockedScreen = nil
            return
        }
        let wasActive = session.phase == .active
        let selectedLayout = session.end()
        let frameTransition: WindowFrameTransition = session.mode == .snap
            ? snapTransition()
            : .immediate
        self.session = nil
        lockedScreen = nil

        let raiseTask = raiseTasks[sessionToken]
        let task = Task { [weak self, windowController] in
            let raiseResult = await raiseTask?.value ?? .succeeded
            let canWriteGeometry: Bool
            switch raiseResult {
            case .succeeded:
                canWriteGeometry = true
            case .cancelled:
                canWriteGeometry = false
            case let .failed(message):
                canWriteGeometry = false
                if !Task.isCancelled {
                    self?.onStatus(message)
                }
            }

            if canWriteGeometry, !Task.isCancelled {
                do {
                    try Task.checkCancellation()
                    var outcome: GestureOutcome?
                    if session.mode == .snap,
                       let selectedLayout,
                       let visibleFrame = session.lockedVisibleFrame {
                        let target = LayoutEngine.targetFrame(for: selectedLayout, in: visibleFrame)
                        _ = try await windowController.applyFrame(
                            target,
                            to: session.window,
                            transition: frameTransition
                        )
                        outcome = .snapped(selectedLayout)
                    } else if session.mode != .snap,
                              wasActive {
                        let finalFrame: CGRect
                        switch session.mode {
                        case .move:
                            finalFrame = WindowFrameCalculator.movedFrame(
                                initialFrame: session.window.frame,
                                from: session.startMouseLocation,
                                to: session.latestMouseLocation
                            )
                            _ = try await windowController.setPosition(
                                finalFrame.origin,
                                of: session.window
                            )
                            outcome = .moved
                        case .resize:
                            finalFrame = WindowFrameCalculator.resizedFrame(
                                initialFrame: session.window.frame,
                                from: session.startMouseLocation,
                                to: session.latestMouseLocation
                            )
                            _ = try await windowController.setSize(
                                finalFrame.size,
                                of: session.window
                            )
                            outcome = .resized
                        case .snap:
                            break
                        }
                    }
                    if let outcome {
                        try Task.checkCancellation()
                        self?.onOutcome(outcome)
                    }
                } catch is CancellationError {
                    // 暂停、撤权或屏幕变化会取消尚未执行的最终写入。
                } catch {
                    if !Task.isCancelled {
                        self?.onStatus(error.localizedDescription)
                    }
                }
            }

            // release 不写窗口，即使任务已取消也必须清理 AX 引用。
            await windowController.release(session.window)
            self?.raiseTasks.removeValue(forKey: sessionToken)
            self?.terminalTasks.removeValue(forKey: terminalToken)
        }
        terminalTasks[terminalToken] = TerminalTask(
            raiseToken: sessionToken,
            task: task
        )
    }

    private func cancelPendingTerminalTasks() {
        let pendingTasks = terminalTasks
        terminalTasks.removeAll()
        for terminalTask in pendingTasks.values {
            terminalTask.task.cancel()
            raiseTasks.removeValue(forKey: terminalTask.raiseToken)?.cancel()
        }
    }

    /// 替换死区内的组合键，或取代已经完整松键但仍未捕获完成的旧手势。
    private func replaceSession(
        with mode: InteractionMode,
        chord: ModifierChord,
        location: CGPoint
    ) {
        let oldToken = generation
        generation &+= 1
        captureTask?.cancel()
        captureTask = nil
        clearPendingCaptureInput()
        motionTask?.cancel()
        motionTask = nil
        pendingMotion = nil
        raiseTasks.removeValue(forKey: oldToken)?.cancel()
        previewController.hide()
        radialClassifier.reset()

        if let session {
            let window = session.window
            Task { [windowController] in
                await windowController.release(window)
            }
        }

        self.session = nil
        lockedScreen = nil
        activeChord = nil
        beginSession(mode: mode, chord: chord, location: location)
    }

    private func startRaiseIfNeeded(_ window: WindowSnapshot, mode: InteractionMode, token: UInt64) {
        guard raiseTasks[token] == nil else { return }

        raiseTasks[token] = Task { [weak self, windowController] in
            let result: WindowRaiseResult
            do {
                try Task.checkCancellation()
                try await windowController.raiseWindow(window)
                await Task.yield()
                try Task.checkCancellation()
                if mode != .snap {
                    try await windowController.beginContinuousInteraction(with: window)
                }
                result = .succeeded
            } catch is CancellationError {
                return .cancelled
            } catch {
                result = .failed(error.localizedDescription)
            }

            // 真实 AXRaise 会同步占用主执行器；无论成功或失败，都先让已经排队的
            // 新输入完成取消，再允许旧会话写几何或报告过期错误。
            await Task.yield()
            guard !Task.isCancelled else { return .cancelled }

            if case let .failed(message) = result,
               let self,
               self.generation == token,
               self.session?.mode == .snap {
                self.raiseTasks.removeValue(forKey: token)
                self.onStatus(message)
                self.cancelCurrentSession()
                return .cancelled
            }
            return result
        }
    }

    private func drainPendingMotionIfNeeded() {
        guard motionTask == nil else { return }
        let token = generation
        let raiseTask = raiseTasks[token]
        motionTask = Task { [weak self, windowController] in
            if let raiseTask {
                let raiseResult = await raiseTask.value
                guard !Task.isCancelled else { return }
                switch raiseResult {
                case .succeeded:
                    break
                case .cancelled:
                    return
                case let .failed(message):
                    guard let self, self.generation == token else { return }
                    self.onStatus(message)
                    self.cancelCurrentSession()
                    return
                }
            }

            while !Task.isCancelled {
                guard let self,
                      self.generation == token,
                      let request = self.pendingMotion
                else {
                    break
                }
                self.pendingMotion = nil

                do {
                    switch request.mode {
                    case .move:
                        try await windowController.updatePosition(
                            request.frame.origin,
                            of: request.window
                        )
                    case .resize:
                        try await windowController.updateSize(
                            request.frame.size,
                            of: request.window
                        )
                    case .snap:
                        break
                    }
                } catch is CancellationError {
                    break
                } catch {
                    guard self.generation == token else { break }
                    self.pendingMotion = nil
                    self.onStatus(error.localizedDescription)
                    self.cancelCurrentSession()
                    return
                }
            }

            guard let self, self.generation == token else { return }
            self.motionTask = nil
            if self.pendingMotion != nil {
                self.drainPendingMotionIfNeeded()
            }
        }
    }

    private func mode(matching chord: ModifierChord) -> InteractionMode? {
        if chord == resizeChord { return .resize }
        if chord == snapChord { return .snap }
        if chord == moveChord { return .move }
        return nil
    }
}
