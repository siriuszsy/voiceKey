import AppKit
import CoreGraphics
import Foundation

enum NSEventMonitorTriggerError: LocalizedError {
    case monitorCreationFailed

    var errorDescription: String? {
        switch self {
        case .monitorCreationFailed:
            return "触发键监听初始化失败。如果这台机器收不到 Fn 触发，再去系统设置里打开键盘监听。"
        }
    }
}

final class NSEventMonitorTriggerEngine: TriggerEngine, @unchecked Sendable {
    weak var delegate: TriggerEngineDelegate?

    private var triggerKey: TriggerKey
    private let intent: SessionIntent
    private var isRunning = false
    private var isTriggerPressed = false
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(initialKey: TriggerKey, intent: SessionIntent = .dictation) {
        triggerKey = initialKey
        self.intent = intent
    }

    func start() throws {
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

    func updateTriggerKey(_ key: TriggerKey) throws {
        triggerKey = key
        isTriggerPressed = false
    }

    private func startOnMainThread() throws {
        guard !isRunning else {
            return
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }

        guard globalMonitor != nil || localMonitor != nil else {
            throw NSEventMonitorTriggerError.monitorCreationFailed
        }

        isRunning = true
    }

    private func stopOnMainThread() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }

        globalMonitor = nil
        localMonitor = nil
        isTriggerPressed = false
        isRunning = false
    }

    private func handle(_ event: NSEvent) {
        guard TriggerKeyMapper.matches(keyCode: CGKeyCode(event.keyCode), triggerKey: triggerKey) else {
            return
        }

        let pressed = isPressed(event: event, triggerKey: triggerKey)
        guard pressed != isTriggerPressed else {
            return
        }

        isTriggerPressed = pressed
        let timestamp = Date().timeIntervalSince1970

        if pressed {
            delegate?.triggerDidPressDown(for: intent, at: timestamp)
        } else {
            delegate?.triggerDidRelease(for: intent, at: timestamp)
        }
    }

    private func isPressed(event: NSEvent, triggerKey: TriggerKey) -> Bool {
        switch triggerKey {
        case .commandSemicolon, .controlCommandSemicolon:
            return false
        case .rightOption:
            return event.modifierFlags.contains(.option)
        case .fn:
            return event.modifierFlags.contains(.function)
        case .fnControl:
            return event.modifierFlags.contains(.function) && event.modifierFlags.contains(.control)
        case .fnShift:
            return event.modifierFlags.contains(.function) && event.modifierFlags.contains(.shift)
        }
    }
}
