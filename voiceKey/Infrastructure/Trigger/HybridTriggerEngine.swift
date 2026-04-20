import Carbon
import Foundation
import OSLog

struct FixedHotKeyShortcut: Sendable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let displayName: String
}

final class HybridTriggerEngine: TriggerEngine, @unchecked Sendable {
    private let logger = Logger(subsystem: BuildInfo.bundleIdentifier, category: "Trigger")

    weak var delegate: TriggerEngineDelegate? {
        didSet {
            dictationCarbonEngine.delegate = delegate
            translationCarbonEngine.delegate = delegate
            modifierChordEngine.delegate = delegate
        }
    }

    private var triggerKey: TriggerKey
    private var translationTriggerKey: TriggerKey
    private var isRunning = false
    private let dictationCarbonEngine: CarbonHotKeyTriggerEngine
    private let translationCarbonEngine: CarbonHotKeyTriggerEngine
    private let modifierChordEngine: ModifierChordTriggerEngine

    init(initialDictationKey: TriggerKey, initialTranslationKey: TriggerKey) {
        self.triggerKey = initialDictationKey
        self.translationTriggerKey = initialTranslationKey
        self.dictationCarbonEngine = CarbonHotKeyTriggerEngine(
            initialKey: initialDictationKey,
            intent: .dictation,
            hotKeyIDValue: 1
        )
        self.translationCarbonEngine = CarbonHotKeyTriggerEngine(
            initialKey: initialTranslationKey,
            intent: .translation,
            hotKeyIDValue: 2
        )
        self.modifierChordEngine = ModifierChordTriggerEngine(
            dictationTrigger: initialDictationKey.requiresInputMonitoring ? initialDictationKey : nil,
            translationTrigger: initialTranslationKey.requiresInputMonitoring ? initialTranslationKey : nil
        )
    }

    func start() throws {
        do {
            try startCarbonTriggerIfNeeded(dictationCarbonEngine, key: triggerKey, scope: "dictation")
            try startCarbonTriggerIfNeeded(translationCarbonEngine, key: translationTriggerKey, scope: "translation")
            try startModifierTriggersIfNeeded()
            isRunning = true
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        dictationCarbonEngine.stop()
        translationCarbonEngine.stop()
        modifierChordEngine.stop()
        isRunning = false
    }

    func updateTriggerKey(_ key: TriggerKey) throws {
        try updateTriggerConfiguration(dictationKey: key, translationKey: translationTriggerKey)
    }

    func updateTriggerConfiguration(dictationKey: TriggerKey, translationKey: TriggerKey) throws {
        let previousDictationKey = triggerKey
        let previousTranslationKey = translationTriggerKey
        let wasRunning = isRunning
        if wasRunning {
            stop()
        }

        do {
            triggerKey = dictationKey
            translationTriggerKey = translationKey
            try dictationCarbonEngine.updateTriggerKey(dictationKey)
            try translationCarbonEngine.updateTriggerKey(translationKey)
            try modifierChordEngine.updateBindings(
                dictationTrigger: dictationKey.requiresInputMonitoring ? dictationKey : nil,
                translationTrigger: translationKey.requiresInputMonitoring ? translationKey : nil
            )

            if wasRunning {
                try start()
            }
        } catch {
            triggerKey = previousDictationKey
            translationTriggerKey = previousTranslationKey
            try? dictationCarbonEngine.updateTriggerKey(previousDictationKey)
            try? translationCarbonEngine.updateTriggerKey(previousTranslationKey)
            try? modifierChordEngine.updateBindings(
                dictationTrigger: previousDictationKey.requiresInputMonitoring ? previousDictationKey : nil,
                translationTrigger: previousTranslationKey.requiresInputMonitoring ? previousTranslationKey : nil
            )
            if wasRunning {
                try? start()
            }
            throw error
        }
    }

    private func startCarbonTriggerIfNeeded(
        _ engine: CarbonHotKeyTriggerEngine,
        key: TriggerKey,
        scope: String
    ) throws {
        guard key.isCarbonCompatible else {
            return
        }

        try engine.start()
        logger.notice("Registered \(scope, privacy: .public) hotkey: \(key.displayName, privacy: .public)")
    }

    private func startModifierTriggersIfNeeded() throws {
        guard modifierChordEngine.hasBindings else {
            return
        }

        try modifierChordEngine.start()
        logger.notice("Registered modifier trigger engine. Dictation: \(self.triggerKey.displayName, privacy: .public), translation: \(self.translationTriggerKey.displayName, privacy: .public)")
    }
}
