import CoreGraphics
import Foundation
import OSLog

enum ModifierChordTriggerError: LocalizedError {
    case tapCreationFailed

    var errorDescription: String? {
        switch self {
        case .tapCreationFailed:
            return "Fn 热键监听初始化失败。如果这台机器收不到 Fn 触发，再去系统设置里打开键盘监听。"
        }
    }
}

struct ModifierTriggerBinding: Equatable, Sendable {
    let intent: SessionIntent
    let triggerKey: TriggerKey

    var modifierCombination: ModifierCombination {
        triggerKey.modifierCombination ?? []
    }
}

final class ModifierChordTriggerEngine: @unchecked Sendable {
    private static let ambiguityDelay: TimeInterval = 0.12

    weak var delegate: TriggerEngineDelegate?

    private let logger = Logger(subsystem: BuildInfo.bundleIdentifier, category: "Trigger")
    private var dictationTrigger: TriggerKey?
    private var translationTrigger: TriggerKey?
    private var isRunning = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var activeBinding: ModifierTriggerBinding?
    private var pendingBinding: ModifierTriggerBinding?
    private var pendingWorkItem: DispatchWorkItem?
    private var currentCombination: ModifierCombination = []
    private var awaitingAllModifiersRelease = false

    init(dictationTrigger: TriggerKey?, translationTrigger: TriggerKey?) {
        self.dictationTrigger = Self.normalizedModifierTrigger(dictationTrigger)
        self.translationTrigger = Self.normalizedModifierTrigger(translationTrigger)
    }

    var hasBindings: Bool {
        !bindings.isEmpty
    }

    func start() throws {
        guard hasBindings else {
            return
        }

        if Thread.isMainThread {
            try startOnMainThread()
            return
        }

        var caughtError: Error?
        DispatchQueue.main.sync {
            do {
                try self.startOnMainThread()
            } catch {
                caughtError = error
            }
        }

        if let caughtError {
            throw caughtError
        }
    }

    func stop() {
        DispatchQueue.main.async {
            self.stopOnMainThread()
        }
    }

    func updateBindings(dictationTrigger: TriggerKey?, translationTrigger: TriggerKey?) throws {
        self.dictationTrigger = Self.normalizedModifierTrigger(dictationTrigger)
        self.translationTrigger = Self.normalizedModifierTrigger(translationTrigger)
        resetState()

        guard isRunning else {
            return
        }

        stopOnMainThread()
        try startOnMainThread()
    }

    private var bindings: [ModifierTriggerBinding] {
        var items: [ModifierTriggerBinding] = []

        if let dictationTrigger {
            items.append(ModifierTriggerBinding(intent: .dictation, triggerKey: dictationTrigger))
        }

        if let translationTrigger {
            items.append(ModifierTriggerBinding(intent: .translation, triggerKey: translationTrigger))
        }

        return items
    }

    private func startOnMainThread() throws {
        guard !isRunning else {
            return
        }

        guard hasBindings else {
            return
        }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: modifierChordTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw ModifierChordTriggerError.tapCreationFailed
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource
        self.isRunning = true
    }

    private func stopOnMainThread() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }

        runLoopSource = nil
        eventTap = nil
        isRunning = false
        resetState()
    }

    private func resetState() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        pendingBinding = nil
        activeBinding = nil
        currentCombination = []
        awaitingAllModifiersRelease = false
    }

    fileprivate func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        _ = proxy

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let combination = normalizedModifierCombination(event.flags)
        currentCombination = combination
        handleCombinationChange(combination, timestamp: Date().timeIntervalSince1970)
        return Unmanaged.passUnretained(event)
    }

    private func handleCombinationChange(
        _ combination: ModifierCombination,
        timestamp: TimeInterval
    ) {
        if awaitingAllModifiersRelease {
            if combination.isEmpty {
                awaitingAllModifiersRelease = false
            } else {
                return
            }
        }

        if let activeBinding, activeBinding.modifierCombination != combination {
            if let promotedBinding = promotedBinding(from: activeBinding, to: combination) {
                transitionActiveBinding(from: activeBinding, to: promotedBinding, timestamp: timestamp)
                return
            }

            release(binding: activeBinding, timestamp: timestamp)
            self.activeBinding = nil
            if !combination.isEmpty {
                cancelPendingBinding()
                awaitingAllModifiersRelease = true
                return
            }
        }

        var canceledPendingBinding = false
        if let pendingBinding, pendingBinding.modifierCombination != combination {
            cancelPendingBinding()
            canceledPendingBinding = true
        }

        guard !awaitingAllModifiersRelease else {
            return
        }

        guard let matchedBinding = exactMatch(for: combination) else {
            if canceledPendingBinding && !combination.isEmpty {
                awaitingAllModifiersRelease = true
            } else if combination.isEmpty {
                cancelPendingBinding()
            }
            return
        }

        guard activeBinding == nil else {
            return
        }

        if requiresDelay(for: matchedBinding) {
            schedulePendingBinding(matchedBinding)
        } else {
            press(binding: matchedBinding, timestamp: timestamp)
        }
    }

    private func exactMatch(for combination: ModifierCombination) -> ModifierTriggerBinding? {
        bindings.first { $0.modifierCombination == combination }
    }

    private func promotedBinding(
        from activeBinding: ModifierTriggerBinding,
        to combination: ModifierCombination
    ) -> ModifierTriggerBinding? {
        guard let candidate = exactMatch(for: combination) else {
            return nil
        }

        guard candidate != activeBinding,
              candidate.modifierCombination.strictlyContains(activeBinding.modifierCombination) else {
            return nil
        }

        return candidate
    }

    private func requiresDelay(for binding: ModifierTriggerBinding) -> Bool {
        bindings.contains { candidate in
            candidate != binding && candidate.modifierCombination.strictlyContains(binding.modifierCombination)
        }
    }

    private func schedulePendingBinding(_ binding: ModifierTriggerBinding) {
        guard pendingBinding != binding else {
            return
        }

        cancelPendingBinding()
        pendingBinding = binding

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            guard self.pendingBinding == binding,
                  self.activeBinding == nil,
                  !self.awaitingAllModifiersRelease,
                  self.currentCombination == binding.modifierCombination else {
                return
            }

            self.press(binding: binding, timestamp: Date().timeIntervalSince1970)
            self.pendingBinding = nil
            self.pendingWorkItem = nil
        }

        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.ambiguityDelay, execute: workItem)
    }

    private func cancelPendingBinding() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        pendingBinding = nil
    }

    private func press(binding: ModifierTriggerBinding, timestamp: TimeInterval) {
        cancelPendingBinding()
        activeBinding = binding
        logger.notice("Modifier trigger pressed: \(binding.triggerKey.displayName, privacy: .public), intent: \(binding.intent.rawValue, privacy: .public)")
        delegate?.triggerDidPressDown(for: binding.intent, at: timestamp)
    }

    private func transitionActiveBinding(
        from previousBinding: ModifierTriggerBinding,
        to newBinding: ModifierTriggerBinding,
        timestamp: TimeInterval
    ) {
        cancelPendingBinding()
        activeBinding = newBinding
        awaitingAllModifiersRelease = false
        logger.notice("Modifier trigger promoted: \(previousBinding.triggerKey.displayName, privacy: .public) -> \(newBinding.triggerKey.displayName, privacy: .public), intent: \(newBinding.intent.rawValue, privacy: .public)")
        delegate?.triggerDidPressDown(for: newBinding.intent, at: timestamp)
    }

    private func release(binding: ModifierTriggerBinding, timestamp: TimeInterval) {
        logger.notice("Modifier trigger released: \(binding.triggerKey.displayName, privacy: .public), intent: \(binding.intent.rawValue, privacy: .public)")
        delegate?.triggerDidRelease(for: binding.intent, at: timestamp)
    }

    private func normalizedModifierCombination(_ flags: CGEventFlags) -> ModifierCombination {
        var combination: ModifierCombination = []

        if flags.contains(.maskSecondaryFn) {
            combination.insert(.fn)
        }
        if flags.contains(.maskControl) {
            combination.insert(.control)
        }
        if flags.contains(.maskShift) {
            combination.insert(.shift)
        }
        if flags.contains(.maskAlternate) {
            combination.insert(.option)
        }

        return combination
    }

    private static func normalizedModifierTrigger(_ trigger: TriggerKey?) -> TriggerKey? {
        guard let trigger, trigger.isModifierTrigger else {
            return nil
        }

        return trigger
    }
}

private let modifierChordTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let engine = Unmanaged<ModifierChordTriggerEngine>
        .fromOpaque(userInfo)
        .takeUnretainedValue()

    return engine.handleEvent(proxy: proxy, type: type, event: event)
}

private extension ModifierCombination {
    func strictlyContains(_ other: ModifierCombination) -> Bool {
        rawValue != other.rawValue && (rawValue & other.rawValue) == other.rawValue
    }
}

#if DEBUG
extension ModifierChordTriggerEngine {
    func debugPrimeActiveBinding(_ binding: ModifierTriggerBinding) {
        activeBinding = binding
        currentCombination = binding.modifierCombination
    }

    func debugHandleCombinationChange(_ combination: ModifierCombination, timestamp: TimeInterval) {
        currentCombination = combination
        handleCombinationChange(combination, timestamp: timestamp)
    }
}
#endif
