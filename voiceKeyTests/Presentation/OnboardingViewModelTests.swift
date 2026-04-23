import XCTest
@testable import voiceKey

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    func testRefreshAPIKeyStatusShowsPersistedButNotLoadedState() {
        let settingsStore = OnboardingSpySettingsStore()
        let sessionAPIKeyStore = OnboardingSpyAPIKeyStore()
        let persistentAPIKeyStore = OnboardingSpyAPIKeyStore(storedValue: "stored-key")
        let permissionService = OnboardingStubPermissionService()
        let probe = FixedTextInsertionProbe(
            contextInspector: OnboardingStubContextInspector(),
            textInserter: FakeTextInserter(),
            hudController: SpyHUDController()
        )
        let viewModel = OnboardingViewModel(
            settingsStore: settingsStore,
            sessionAPIKeyStore: sessionAPIKeyStore,
            persistentAPIKeyStore: persistentAPIKeyStore,
            permissionService: permissionService,
            fixedTextInsertionProbe: probe,
            environmentProvider: { [:] },
            onFinish: {}
        )

        XCTAssertEqual(viewModel.apiKeyAvailability, .persistedButNotLoaded)
        XCTAssertEqual(viewModel.apiKeyStatusText, "本机安全存储中已保存 API Key，当前会话未加载。")
        XCTAssertEqual(persistentAPIKeyStore.loadCallCount, 0)
        XCTAssertEqual(viewModel.apiKeyInput, "")
    }

    func testUseAPIKeyForCurrentSessionKeepsVisibleInput() {
        let settingsStore = OnboardingSpySettingsStore()
        let sessionAPIKeyStore = OnboardingSpyAPIKeyStore()
        let persistentAPIKeyStore = OnboardingSpyAPIKeyStore()
        let permissionService = OnboardingStubPermissionService()
        let probe = FixedTextInsertionProbe(
            contextInspector: OnboardingStubContextInspector(),
            textInserter: FakeTextInserter(),
            hudController: SpyHUDController()
        )
        let viewModel = OnboardingViewModel(
            settingsStore: settingsStore,
            sessionAPIKeyStore: sessionAPIKeyStore,
            persistentAPIKeyStore: persistentAPIKeyStore,
            permissionService: permissionService,
            fixedTextInsertionProbe: probe,
            environmentProvider: { [:] },
            onFinish: {}
        )

        viewModel.apiKeyInput = "  session-key  "
        viewModel.useAPIKeyForCurrentSession()

        XCTAssertEqual(viewModel.apiKeyInput, "session-key")
        XCTAssertEqual(viewModel.apiKeyAvailability, .sessionLoaded)
    }
}

private final class OnboardingSpySettingsStore: SettingsStore {
    var settings = AppSettings.default

    func load() throws -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) throws {
        self.settings = settings
    }
}

private final class OnboardingSpyAPIKeyStore: APIKeyStore {
    private let storedValue: String?
    private(set) var loadCallCount: Int = 0

    init(storedValue: String? = nil) {
        self.storedValue = storedValue
    }

    func save(_ key: String) throws {
        _ = key
    }

    func load() throws -> String {
        loadCallCount += 1
        if let storedValue {
            return storedValue
        }
        throw NSError(domain: "OnboardingViewModelTests", code: 1)
    }

    func hasStoredKey() -> Bool {
        if let storedValue {
            return !storedValue.isEmpty
        }
        return false
    }
}

private final class OnboardingStubPermissionService: PermissionService {
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

private struct OnboardingStubContextInspector: ContextInspector {
    func currentContext() throws -> FocusedContext {
        FocusedContext(
            bundleIdentifier: BuildInfo.bundleIdentifier,
            applicationName: BuildInfo.displayName,
            processIdentifier: nil,
            windowTitle: nil,
            elementRole: nil,
            isEditable: true,
            focusedElement: nil
        )
    }
}
