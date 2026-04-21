import Foundation
import XCTest
@testable import voiceKey

final class SelectableASRServiceTests: XCTestCase {
    func testTranscribeFallsBackToOfflineWhenRealtimeModeFails() async throws {
        let settingsStore = MutableSettingsStore(asrMode: .realtime)
        let offlineService = RecordingASRService(
            transcript: ASRTranscript(rawText: "offline result", languageCode: "zh")
        )
        let realtimeService = RecordingASRService(
            transcript: ASRTranscript(rawText: "realtime result", languageCode: "zh"),
            error: DictationError.asrFailed("实时链路启动失败")
        )
        let service = SelectableASRService(
            settingsStore: settingsStore,
            offlineService: offlineService,
            realtimeService: realtimeService
        )

        let transcript = try await service.transcribe(makePayload())
        let realtimeTranscribeCallCount = await realtimeService.transcribeCallCount
        let offlineTranscribeCallCount = await offlineService.transcribeCallCount

        XCTAssertEqual(transcript.rawText, "offline result")
        XCTAssertEqual(realtimeTranscribeCallCount, 1)
        XCTAssertEqual(offlineTranscribeCallCount, 1)
    }

    func testTranscribeUsesOfflineImmediatelyAfterModeSwitch() async throws {
        let settingsStore = MutableSettingsStore(asrMode: .realtime)
        let offlineService = RecordingASRService(
            transcript: ASRTranscript(rawText: "offline result", languageCode: "zh")
        )
        let realtimeService = RecordingASRService(
            transcript: ASRTranscript(rawText: "realtime result", languageCode: "zh")
        )
        let service = SelectableASRService(
            settingsStore: settingsStore,
            offlineService: offlineService,
            realtimeService: realtimeService
        )

        settingsStore.settings.asrMode = .offline
        let transcript = try await service.transcribe(makePayload())
        let realtimeTranscribeCallCount = await realtimeService.transcribeCallCount
        let offlineTranscribeCallCount = await offlineService.transcribeCallCount

        XCTAssertEqual(transcript.rawText, "offline result")
        XCTAssertEqual(realtimeTranscribeCallCount, 0)
        XCTAssertEqual(offlineTranscribeCallCount, 1)
    }

    func testBeginLiveTranscriptionReturnsFalseOutsideRealtimeMode() async throws {
        let settingsStore = MutableSettingsStore(asrMode: .offline)
        let offlineService = RecordingASRService(
            transcript: ASRTranscript(rawText: "offline result", languageCode: "zh")
        )
        let realtimeService = RecordingASRService(
            transcript: ASRTranscript(rawText: "realtime result", languageCode: "zh"),
            liveStartResult: true
        )
        let service = SelectableASRService(
            settingsStore: settingsStore,
            offlineService: offlineService,
            realtimeService: realtimeService
        )

        let started = try await service.beginLiveTranscription(languageCode: nil)
        let realtimeBeginLiveCallCount = await realtimeService.beginLiveCallCount

        XCTAssertFalse(started)
        XCTAssertEqual(realtimeBeginLiveCallCount, 0)
    }

    private func makePayload() -> AudioPayload {
        AudioPayload(
            fileURL: URL(fileURLWithPath: "/tmp/test.wav"),
            format: "wav",
            sampleRate: 16_000,
            durationMs: 320
        )
    }
}

private final class MutableSettingsStore: SettingsStore {
    var settings: AppSettings

    init(asrMode: ASRMode) {
        var settings = AppSettings.default
        settings.asrMode = asrMode
        self.settings = settings
    }

    func load() throws -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) throws {
        self.settings = settings
    }
}

private actor RecordingASRService: ASRService, LiveStreamingASRService {
    private(set) var transcribeCallCount = 0
    private(set) var beginLiveCallCount = 0

    let transcript: ASRTranscript
    let error: Error?
    let liveStartResult: Bool

    init(
        transcript: ASRTranscript,
        error: Error? = nil,
        liveStartResult: Bool = false
    ) {
        self.transcript = transcript
        self.error = error
        self.liveStartResult = liveStartResult
    }

    nonisolated func transcribe(_ payload: AudioPayload) async throws -> ASRTranscript {
        _ = payload
        await incrementTranscribeCount()
        if let error {
            throw error
        }
        return transcript
    }

    nonisolated func beginLiveTranscription(languageCode: String?) async throws -> Bool {
        _ = languageCode
        await incrementBeginLiveCount()
        if let error {
            throw error
        }
        return liveStartResult
    }

    nonisolated func appendLiveAudioChunk(_ chunk: AudioChunk) async throws {
        _ = chunk
    }

    nonisolated func finishLiveTranscription() async throws -> ASRTranscript? {
        transcript
    }

    nonisolated func cancelLiveTranscription() async {}

    private func incrementTranscribeCount() {
        transcribeCallCount += 1
    }

    private func incrementBeginLiveCount() {
        beginLiveCallCount += 1
    }
}
