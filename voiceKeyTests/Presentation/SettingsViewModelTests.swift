import XCTest
@testable import voiceKey

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testApplyASRModeChangePersistsImmediately() throws {
        let settingsStore = SpySettingsStore()
        settingsStore.settings.asrMode = .realtime
        let sessionAPIKeyStore = SpyAPIKeyStore()
        let persistentAPIKeyStore = SpyAPIKeyStore()
        let permissionService = StubPermissionService()
        var appliedTransitions: [(AppSettings, AppSettings)] = []
        let viewModel = SettingsViewModel(
            settingsStore: settingsStore,
            sessionAPIKeyStore: sessionAPIKeyStore,
            persistentAPIKeyStore: persistentAPIKeyStore,
            permissionService: permissionService,
            applySettings: { previousSettings, settings in
                appliedTransitions.append((previousSettings, settings))
            },
            environmentProvider: { [:] }
        )

        viewModel.settings.asrMode = .offline
        viewModel.applyASRModeChange()

        XCTAssertEqual(try settingsStore.load().asrMode, .offline)
        XCTAssertEqual(appliedTransitions.last?.0.asrMode, .realtime)
        XCTAssertEqual(appliedTransitions.last?.1.asrMode, .offline)
        XCTAssertEqual(viewModel.saveMessage, "识别模式已切换并已生效")
    }

    func testApplyASRModeChangeIsNotBlockedByOtherUnsavedInvalidFields() throws {
        let settingsStore = SpySettingsStore()
        settingsStore.settings.asrMode = .realtime
        let sessionAPIKeyStore = SpyAPIKeyStore()
        let persistentAPIKeyStore = SpyAPIKeyStore()
        let permissionService = StubPermissionService()
        let viewModel = SettingsViewModel(
            settingsStore: settingsStore,
            sessionAPIKeyStore: sessionAPIKeyStore,
            persistentAPIKeyStore: persistentAPIKeyStore,
            permissionService: permissionService,
            applySettings: nil,
            environmentProvider: { [:] }
        )

        viewModel.settings.translationTargetLanguage = "auto"
        viewModel.settings.asrMode = .offline
        viewModel.applyASRModeChange()

        let persistedSettings = try settingsStore.load()
        XCTAssertEqual(persistedSettings.asrMode, .offline)
        XCTAssertEqual(persistedSettings.translationTargetLanguage, "English")
    }

    func testInitDoesNotReadPersistentStore() {
        let settingsStore = SpySettingsStore()
        let sessionAPIKeyStore = SpyAPIKeyStore()
        let persistentAPIKeyStore = SpyAPIKeyStore()
        let permissionService = StubPermissionService()

        _ = SettingsViewModel(
            settingsStore: settingsStore,
            sessionAPIKeyStore: sessionAPIKeyStore,
            persistentAPIKeyStore: persistentAPIKeyStore,
            permissionService: permissionService,
            environmentProvider: { [:] }
        )

        XCTAssertEqual(sessionAPIKeyStore.loadCallCount, 1)
        XCTAssertEqual(persistentAPIKeyStore.loadCallCount, 0)
    }

    func testUseAPIKeyForCurrentSessionOnlyTouchesSessionStore() {
        let settingsStore = SpySettingsStore()
        let sessionAPIKeyStore = SpyAPIKeyStore()
        let persistentAPIKeyStore = SpyAPIKeyStore()
        let permissionService = StubPermissionService()
        let viewModel = SettingsViewModel(
            settingsStore: settingsStore,
            sessionAPIKeyStore: sessionAPIKeyStore,
            persistentAPIKeyStore: persistentAPIKeyStore,
            permissionService: permissionService,
            environmentProvider: { [:] }
        )

        viewModel.apiKeyInput = "  session-key  "
        viewModel.useAPIKeyForCurrentSession()

        XCTAssertEqual(sessionAPIKeyStore.savedKeys, ["session-key"])
        XCTAssertTrue(persistentAPIKeyStore.savedKeys.isEmpty)
        XCTAssertEqual(viewModel.apiKeyAvailability, .sessionLoaded)
    }

    func testSaveAPIKeyToPersistentStoreAlsoLoadsCurrentSession() {
        let settingsStore = SpySettingsStore()
        let sessionAPIKeyStore = SpyAPIKeyStore()
        let persistentAPIKeyStore = SpyAPIKeyStore()
        let permissionService = StubPermissionService()
        let viewModel = SettingsViewModel(
            settingsStore: settingsStore,
            sessionAPIKeyStore: sessionAPIKeyStore,
            persistentAPIKeyStore: persistentAPIKeyStore,
            permissionService: permissionService,
            environmentProvider: { [:] }
        )

        viewModel.apiKeyInput = "saved-key"
        viewModel.saveAPIKeyToPersistentStore()

        XCTAssertEqual(sessionAPIKeyStore.savedKeys, ["saved-key"])
        XCTAssertEqual(persistentAPIKeyStore.savedKeys, ["saved-key"])
        XCTAssertEqual(viewModel.apiKeyAvailability, .sessionLoaded)
    }

    func testLoadSavedAPIKeyRequiresExplicitAction() {
        let settingsStore = SpySettingsStore()
        let sessionAPIKeyStore = SpyAPIKeyStore()
        let persistentAPIKeyStore = SpyAPIKeyStore(storedValue: "stored-key")
        let permissionService = StubPermissionService()
        let viewModel = SettingsViewModel(
            settingsStore: settingsStore,
            sessionAPIKeyStore: sessionAPIKeyStore,
            persistentAPIKeyStore: persistentAPIKeyStore,
            permissionService: permissionService,
            environmentProvider: { [:] }
        )

        XCTAssertEqual(persistentAPIKeyStore.loadCallCount, 0)

        viewModel.loadSavedAPIKeyIntoCurrentSession()

        XCTAssertEqual(persistentAPIKeyStore.loadCallCount, 1)
        XCTAssertEqual(sessionAPIKeyStore.savedKeys, ["stored-key"])
        XCTAssertEqual(viewModel.apiKeyAvailability, .sessionLoaded)
    }

    func testEnvironmentAPIKeyWinsWithoutTouchingStores() {
        let settingsStore = SpySettingsStore()
        let sessionAPIKeyStore = SpyAPIKeyStore()
        let persistentAPIKeyStore = SpyAPIKeyStore()
        let permissionService = StubPermissionService()
        let viewModel = SettingsViewModel(
            settingsStore: settingsStore,
            sessionAPIKeyStore: sessionAPIKeyStore,
            persistentAPIKeyStore: persistentAPIKeyStore,
            permissionService: permissionService,
            environmentProvider: { ["DASHSCOPE_API_KEY": "env-key"] }
        )

        XCTAssertEqual(viewModel.apiKeyAvailability, .environmentProvided)
        XCTAssertEqual(sessionAPIKeyStore.loadCallCount, 0)
        XCTAssertEqual(persistentAPIKeyStore.loadCallCount, 0)
    }
}

private final class SpySettingsStore: SettingsStore {
    var settings = AppSettings.default

    func load() throws -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) throws {
        self.settings = settings
    }
}

private final class SpyAPIKeyStore: APIKeyStore {
    private let storedValue: String?
    private(set) var savedKeys: [String] = []
    private(set) var loadCallCount: Int = 0

    init(storedValue: String? = nil) {
        self.storedValue = storedValue
    }

    func save(_ key: String) throws {
        savedKeys.append(key)
    }

    func load() throws -> String {
        loadCallCount += 1
        if let storedValue {
            return storedValue
        }
        throw NSError(domain: "SettingsViewModelTests", code: 1)
    }
}

private final class StubPermissionService: PermissionService {
    func currentStatus() -> SystemPermissionStatus {
        SystemPermissionStatus(
            inputMonitoring: .notRequired,
            accessibility: .granted,
            microphone: .granted
        )
    }

    func requestAccessibilityAccess() -> Bool {
        true
    }

    func requestMicrophoneAccess(completion: @escaping @Sendable (Bool) -> Void) {
        completion(true)
    }

    func openSystemSettings(for permission: SystemPermissionKind) -> Bool {
        _ = permission
        return true
    }
}
