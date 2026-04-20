import Foundation

protocol TriggerEngine: AnyObject {
    var delegate: TriggerEngineDelegate? { get set }
    func start() throws
    func stop()
    func updateTriggerKey(_ key: TriggerKey) throws
}

protocol TriggerEngineDelegate: AnyObject {
    func triggerDidPressDown(for intent: SessionIntent, at timestamp: TimeInterval)
    func triggerDidRelease(for intent: SessionIntent, at timestamp: TimeInterval)
}

enum TriggerKey: String, Codable, Sendable {
    case commandSemicolon
    case controlCommandSemicolon
    case rightOption
    case fn
    case fnControl
    case fnShift

    var displayName: String {
        switch self {
        case .commandSemicolon:
            return "⌘ + ;"
        case .controlCommandSemicolon:
            return "⌃⌘ + ;"
        case .rightOption:
            return "右侧 ⌥"
        case .fn:
            return "Fn"
        case .fnControl:
            return "Fn + Control"
        case .fnShift:
            return "Fn + Shift"
        }
    }

    var requiresInputMonitoring: Bool {
        switch self {
        case .commandSemicolon, .controlCommandSemicolon:
            return false
        case .rightOption, .fn, .fnControl, .fnShift:
            return true
        }
    }

    var isCarbonCompatible: Bool {
        switch self {
        case .commandSemicolon, .controlCommandSemicolon:
            return true
        case .rightOption, .fn, .fnControl, .fnShift:
            return false
        }
    }

    var isModifierTrigger: Bool {
        modifierCombination != nil
    }

    var isFnFamilyTrigger: Bool {
        switch self {
        case .fn, .fnControl, .fnShift:
            return true
        case .commandSemicolon, .controlCommandSemicolon, .rightOption:
            return false
        }
    }

    var modifierCombination: ModifierCombination? {
        switch self {
        case .commandSemicolon, .controlCommandSemicolon:
            return nil
        case .rightOption:
            return [.option]
        case .fn:
            return [.fn]
        case .fnControl:
            return [.fn, .control]
        case .fnShift:
            return [.fn, .shift]
        }
    }

    static let dictationChoices: [TriggerKey] = [
        .fn,
        .fnShift,
        .fnControl
    ]

    static let translationChoices: [TriggerKey] = [
        .fnControl,
        .fnShift,
        .fn
    ]
}

struct ModifierCombination: OptionSet, Codable, Sendable, Hashable {
    let rawValue: Int

    static let fn = ModifierCombination(rawValue: 1 << 0)
    static let control = ModifierCombination(rawValue: 1 << 1)
    static let shift = ModifierCombination(rawValue: 1 << 2)
    static let option = ModifierCombination(rawValue: 1 << 3)
}
