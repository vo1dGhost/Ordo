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

    private let windowController: any WindowControlling
    private let screenProvider: any ScreenGeometryProviding
    private let previewController: any PreviewDisplaying
    private let onStatus: @MainActor (String) -> Void

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
    private var pendingFinishAfterCapture: ModifierChord?
    private var raiseTasks: [UInt64: Task<Bool, Never>] = [:]
    private var terminalTasks: [UInt64: Task<Void, Never>] = [:]
    private var generation: UInt64 = 0
    private var requiresFullModifierRelease = false
    private var currentModifiers: ModifierChord = []

    init(
        windowController: any WindowControlling,
        screenProvider: any ScreenGeometryProviding,
        previewController: any PreviewDisplaying,
        onStatus: @escaping @MainActor (String) -> Void
    ) {
        self.windowController = windowController
        self.screenProvider = screenProvider
        self.previewController = previewController
        self.onStatus = onStatus
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
        }
    }

    /// 权限撤销、暂停或屏幕参数变化都会终止当前会话，且不提交排布。
    @discardableResult
    func cancelCurrentSession() -> Bool {
        let hadActiveChord = activeChord != nil
        let hadActiveWork = hadActiveChord || session != nil || !terminalTasks.isEmpty
        generation &+= 1
        captureTask?.cancel()
        captureTask = nil
        pendingCaptureMouseLocations.removeAll(keepingCapacity: true)
        pendingFinishAfterCapture = nil
        motionTask?.cancel()
        motionTask = nil
        for task in raiseTasks.values {
            task.cancel()
        }
        raiseTasks.removeAll()
        for task in terminalTasks.values {
            task.cancel()
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
        requiresFullModifierRelease = hadActiveChord && !currentModifiers.isEmpty
        return hadActiveWork
    }

    private func handleModifierChange(_ event: InputEvent) {
        currentModifiers = event.modifiers
        if requiresFullModifierRelease {
            if event.modifiers.isEmpty {
                requiresFullModifierRelease = false
            }
            return
        }

        if let activeChord {
            if event.modifiers != activeChord,
               event.modifiers.contains(activeChord),
               let replacementMode = mode(matching: event.modifiers),
               session?.phase != .active,
               pendingFinishAfterCapture == nil {
                replaceTrackingSession(
                    with: replacementMode,
                    chord: event.modifiers,
                    location: event.location
                )
                return
            }

            // 激活后忽略额外修饰键；任一必要修饰键松开即提交。
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
        generation &+= 1
        let token = generation
        activeChord = chord
        pendingCaptureMouseLocations.removeAll(keepingCapacity: true)
        pendingFinishAfterCapture = nil
        radialClassifier.reset()

        let screen = mode == .snap ? screenProvider.screen(containingAXPoint: location) : nil
        if mode == .snap, screen == nil {
            activeChord = nil
            requiresFullModifierRelease = true
            onStatus("无法确定鼠标所在屏幕")
            return
        }
        lockedScreen = screen

        captureTask = Task { [weak self, windowController] in
            do {
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
                self.pendingCaptureMouseLocations.removeAll(keepingCapacity: true)
                self.pendingFinishAfterCapture = nil
                self.activeChord = nil
                self.requiresFullModifierRelease = !self.currentModifiers.isEmpty
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

        if let activeChord {
            if event.modifiers != activeChord,
               event.modifiers.contains(activeChord),
               let replacementMode = mode(matching: event.modifiers),
               session?.phase != .active,
               pendingFinishAfterCapture == nil {
                replaceTrackingSession(
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
                startRaiseIfNeeded(session.window, token: generation)
            }
            if let selectedLayout,
               let screen = lockedScreen,
               let visibleFrame = session.lockedVisibleFrame
            {
                previewController.show(
                    layout: selectedLayout,
                    targetFrame: LayoutEngine.targetFrame(for: selectedLayout, in: visibleFrame),
                    screen: screen
                )
            } else {
                previewController.hide()
            }

        case .move, .resize:
            self.session = session
            guard session.phase == .active else {
                return
            }
            if becameActive {
                startRaiseIfNeeded(session.window, token: generation)
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
        pendingCaptureMouseLocations.removeAll(keepingCapacity: true)
        pendingFinishAfterCapture = nil
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
        let selectedLayout = session.end()
        self.session = nil
        lockedScreen = nil

        let raiseTask = raiseTasks[sessionToken]
        let task = Task { [weak self, windowController] in
            let raisedSuccessfully = await raiseTask?.value ?? true

            if raisedSuccessfully, !Task.isCancelled {
                do {
                    try Task.checkCancellation()
                    if session.mode == .snap,
                       let selectedLayout,
                       let visibleFrame = session.lockedVisibleFrame {
                        let target = LayoutEngine.targetFrame(for: selectedLayout, in: visibleFrame)
                        _ = try await windowController.applyFrame(target, to: session.window)
                    } else if session.mode != .snap,
                              session.distanceFromStart > session.activationThreshold {
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
                        case .snap:
                            break
                        }
                    }
                } catch is CancellationError {
                    // 暂停、撤权或屏幕变化会取消尚未执行的最终写入。
                } catch {
                    self?.onStatus(error.localizedDescription)
                }
            }

            // release 不写窗口，即使任务已取消也必须清理 AX 引用。
            await windowController.release(session.window)
            self?.raiseTasks.removeValue(forKey: sessionToken)
            self?.terminalTasks.removeValue(forKey: terminalToken)
        }
        terminalTasks[terminalToken] = task
    }

    /// 较长组合键包含较短组合键时，允许在死区内切换到新的精确组合。
    private func replaceTrackingSession(
        with mode: InteractionMode,
        chord: ModifierChord,
        location: CGPoint
    ) {
        let oldToken = generation
        generation &+= 1
        captureTask?.cancel()
        captureTask = nil
        pendingCaptureMouseLocations.removeAll(keepingCapacity: true)
        pendingFinishAfterCapture = nil
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

    private func startRaiseIfNeeded(_ window: WindowSnapshot, token: UInt64) {
        guard raiseTasks[token] == nil else { return }

        let task = Task { [weak self, windowController] () -> Bool in
            do {
                try Task.checkCancellation()
                try await windowController.activateAndRaise(window)
                try Task.checkCancellation()
                return true
            } catch is CancellationError {
                return false
            } catch {
                guard let self, self.generation == token else { return false }
                self.onStatus(error.localizedDescription)
                self.cancelCurrentSession()
                return false
            }
        }
        raiseTasks[token] = task
    }

    private func drainPendingMotionIfNeeded() {
        guard motionTask == nil else { return }
        let token = generation
        let raiseTask = raiseTasks[token]
        motionTask = Task { [weak self, windowController] in
            if let raiseTask, !(await raiseTask.value) {
                return
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
                        _ = try await windowController.setPosition(
                            request.frame.origin,
                            of: request.window
                        )
                    case .resize:
                        _ = try await windowController.setSize(
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
