import XCTest
@testable import voiceKey

final class DictationOrchestratorTests: XCTestCase {
    func testTranslationIntentTranslatesAndSkipsCleanup() async throws {
        let triggerEngine = FakeTriggerEngine()
        let recordingEngine = StubRecordingEngine()
        let asrService = StubASRService()
        let translationService = StubTranslationService()
        let cleanupService = StubCleanupService()
        let contextInspector = StubContextInspector()
        let textInserter = StubTextInserter()
        let hudController = SpyHUDController()
        let logStore = StubSessionLogStore()
        let settingsStore = StubSettingsStore()
        let orchestrator = DictationOrchestrator(
            triggerEngine: triggerEngine,
            recordingEngine: recordingEngine,
            asrService: asrService,
            translationService: translationService,
            cleanupService: cleanupService,
            contextInspector: contextInspector,
            textInserter: textInserter,
            hudController: hudController,
            sessionLogStore: logStore,
            clock: StubClock(),
            settingsStore: settingsStore
        )

        triggerEngine.delegate = orchestrator
        recordingEngine.levelObserver = orchestrator
        recordingEngine.chunkObserver = orchestrator

        triggerEngine.triggerDown(intent: .translation, at: 1)
        triggerEngine.triggerUp(intent: .translation, at: 2)
        await fulfillment(of: [processingExpectation {
            !textInserter.insertedTexts.isEmpty
        }], timeout: 1)

        XCTAssertEqual(cleanupService.invocationCount, 0)
        XCTAssertEqual(translationService.receivedTexts, ["ni hao"])
        XCTAssertEqual(translationService.receivedOptions.first?.sourceLanguage, "auto")
        XCTAssertEqual(translationService.receivedOptions.first?.targetLanguage, "English")
        XCTAssertEqual(textInserter.insertedTexts, ["hello"])
    }

    func testTranslationFailureDoesNotInsertRawTranscript() async throws {
        let triggerEngine = FakeTriggerEngine()
        let recordingEngine = StubRecordingEngine()
        let asrService = StubASRService()
        let translationService = StubTranslationService()
        translationService.error = DictationError.translationFailed("翻译服务异常")
        let cleanupService = StubCleanupService()
        let contextInspector = StubContextInspector()
        let textInserter = StubTextInserter()
        let hudController = SpyHUDController()
        let logStore = StubSessionLogStore()
        let settingsStore = StubSettingsStore()
        let orchestrator = DictationOrchestrator(
            triggerEngine: triggerEngine,
            recordingEngine: recordingEngine,
            asrService: asrService,
            translationService: translationService,
            cleanupService: cleanupService,
            contextInspector: contextInspector,
            textInserter: textInserter,
            hudController: hudController,
            sessionLogStore: logStore,
            clock: StubClock(),
            settingsStore: settingsStore
        )

        triggerEngine.delegate = orchestrator
        recordingEngine.levelObserver = orchestrator
        recordingEngine.chunkObserver = orchestrator

        triggerEngine.triggerDown(intent: .translation, at: 1)
        triggerEngine.triggerUp(intent: .translation, at: 2)
        await fulfillment(of: [processingExpectation {
            if case .failed = orchestrator.state {
                return true
            }
            return false
        }], timeout: 1)

        XCTAssertEqual(cleanupService.invocationCount, 0)
        XCTAssertTrue(textInserter.insertedTexts.isEmpty)
    }

    func testPromotingRecordingIntentToTranslationKeepsRecordingAndIgnoresStaleDictationRelease() async throws {
        let triggerEngine = FakeTriggerEngine()
        let recordingEngine = StubRecordingEngine()
        let asrService = StubASRService()
        let translationService = StubTranslationService()
        let cleanupService = StubCleanupService()
        let contextInspector = StubContextInspector()
        let textInserter = StubTextInserter()
        let hudController = SpyHUDController()
        let logStore = StubSessionLogStore()
        let settingsStore = StubSettingsStore()
        let orchestrator = DictationOrchestrator(
            triggerEngine: triggerEngine,
            recordingEngine: recordingEngine,
            asrService: asrService,
            translationService: translationService,
            cleanupService: cleanupService,
            contextInspector: contextInspector,
            textInserter: textInserter,
            hudController: hudController,
            sessionLogStore: logStore,
            clock: StubClock(),
            settingsStore: settingsStore
        )

        triggerEngine.delegate = orchestrator
        recordingEngine.levelObserver = orchestrator
        recordingEngine.chunkObserver = orchestrator

        triggerEngine.triggerDown(intent: .dictation, at: 1)
        triggerEngine.triggerDown(intent: .translation, at: 1.2)
        triggerEngine.triggerUp(intent: .dictation, at: 1.3)
        triggerEngine.triggerUp(intent: .translation, at: 2)
        await fulfillment(of: [processingExpectation {
            !textInserter.insertedTexts.isEmpty
        }], timeout: 1)

        XCTAssertEqual(recordingEngine.stopRecordingCallCount, 1)
        XCTAssertEqual(cleanupService.invocationCount, 0)
        XCTAssertEqual(translationService.receivedTexts, ["ni hao"])
        XCTAssertEqual(textInserter.insertedTexts, ["hello"])

        let listeningStates = hudController.renderedStates.compactMap { state -> SessionIntent? in
            guard case .listening(let intent, _) = state else {
                return nil
            }
            return intent
        }
        XCTAssertEqual(listeningStates.suffix(2), [.dictation, .translation])
    }

    private func processingExpectation(_ condition: @escaping @Sendable () -> Bool) -> XCTestExpectation {
        let expectation = expectation(description: "condition satisfied")
        Task {
            let deadline = Date().addingTimeInterval(1)
            while Date() < deadline {
                if condition() {
                    expectation.fulfill()
                    return
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
        return expectation
    }
}

private final class StubASRService: ASRService, @unchecked Sendable {
    var transcript = ASRTranscript(rawText: "ni hao", languageCode: "zh")

    func transcribe(_ payload: AudioPayload) async throws -> ASRTranscript {
        _ = payload
        return transcript
    }
}

private final class StubTranslationService: TranslationService, @unchecked Sendable {
    var translatedText = "hello"
    var error: Error?
    private(set) var receivedTexts: [String] = []
    private(set) var receivedOptions: [TranslationOptions] = []

    func translate(_ text: String, options: TranslationOptions) async throws -> String {
        receivedTexts.append(text)
        receivedOptions.append(options)
        if let error {
            throw error
        }
        return translatedText
    }
}

private final class StubCleanupService: CleanupService {
    private(set) var invocationCount = 0

    func cleanup(transcript: ASRTranscript, context: CleanupContext) async throws -> CleanText {
        _ = transcript
        _ = context
        invocationCount += 1
        return CleanText(value: "clean text")
    }
}

private final class StubRecordingEngine: RecordingEngine {
    weak var levelObserver: RecordingLevelObserving?
    weak var chunkObserver: RecordingChunkObserving?
    private(set) var stopRecordingCallCount = 0

    func prepare() async throws {}
    func startRecording() throws {}

    func stopRecording() async throws -> AudioPayload {
        stopRecordingCallCount += 1
        return AudioPayload(
            fileURL: URL(fileURLWithPath: "/tmp/test.wav"),
            format: "wav",
            sampleRate: 16_000,
            durationMs: 300
        )
    }
}

private final class StubContextInspector: ContextInspector {
    func currentContext() throws -> FocusedContext {
        FocusedContext(
            bundleIdentifier: "com.example.app",
            applicationName: "Example",
            processIdentifier: nil,
            windowTitle: nil,
            elementRole: nil,
            isEditable: true,
            focusedElement: nil
        )
    }
}

private final class StubTextInserter: TextInserter, @unchecked Sendable {
    private(set) var insertedTexts: [String] = []

    func insert(_ text: String, into context: FocusedContext) throws -> InsertionResult {
        _ = context
        insertedTexts.append(text)
        return InsertionResult(success: true, usedFallback: false, failureReason: nil)
    }
}

private final class StubSessionLogStore: SessionLogStore {
    func append(_ record: SessionRecord) async {
        _ = record
    }
}

private struct StubClock: Clock {
    func now() -> Date {
        Date(timeIntervalSince1970: 1)
    }
}

private final class StubSettingsStore: SettingsStore {
    var settings = AppSettings.default

    init() {
        settings.translationSourceLanguage = "auto"
        settings.translationTargetLanguage = "English"
    }

    func load() throws -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) throws {
        self.settings = settings
    }
}
