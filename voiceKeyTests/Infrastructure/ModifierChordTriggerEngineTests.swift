import XCTest
@testable import voiceKey

final class ModifierChordTriggerEngineTests: XCTestCase {
    func testPromotesFnDictationToFnControlTranslationWithoutIntermediateRelease() {
        let engine = ModifierChordTriggerEngine(dictationTrigger: .fn, translationTrigger: .fnControl)
        let delegate = TriggerEventRecorder()
        engine.delegate = delegate

        engine.debugPrimeActiveBinding(
            ModifierTriggerBinding(intent: .dictation, triggerKey: .fn)
        )

        engine.debugHandleCombinationChange([.fn, .control], timestamp: 2)
        engine.debugHandleCombinationChange([], timestamp: 3)

        XCTAssertEqual(
            delegate.events,
            [
                "down:translation@2.0",
                "up:translation@3.0"
            ]
        )
    }
}

private final class TriggerEventRecorder: TriggerEngineDelegate {
    private(set) var events: [String] = []

    func triggerDidPressDown(for intent: SessionIntent, at timestamp: TimeInterval) {
        events.append("down:\(intent.rawValue)@\(timestamp)")
    }

    func triggerDidRelease(for intent: SessionIntent, at timestamp: TimeInterval) {
        events.append("up:\(intent.rawValue)@\(timestamp)")
    }
}
