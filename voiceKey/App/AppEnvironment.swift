import Foundation

final class AppEnvironment {
    let settingsStore: SettingsStore
    let sessionAPIKeyStore: APIKeyStore
    let persistentAPIKeyStore: APIKeyStore
    let permissionService: PermissionService
    let sessionLogStore: SessionLogStore
    let triggerEngine: TriggerEngine
    let recordingEngine: RecordingEngine
    let asrService: ASRService
    let cleanupService: CleanupService
    let contextInspector: ContextInspector
    let textInserter: TextInserter
    let hudController: StatusHUDControlling
    let orchestrator: DictationOrchestrator
    let fixedTextInsertionProbe: FixedTextInsertionProbe

    init(
        settingsStore: SettingsStore,
        sessionAPIKeyStore: APIKeyStore,
        persistentAPIKeyStore: APIKeyStore,
        permissionService: PermissionService,
        sessionLogStore: SessionLogStore,
        triggerEngine: TriggerEngine,
        recordingEngine: RecordingEngine,
        asrService: ASRService,
        cleanupService: CleanupService,
        contextInspector: ContextInspector,
        textInserter: TextInserter,
        hudController: StatusHUDControlling,
        orchestrator: DictationOrchestrator,
        fixedTextInsertionProbe: FixedTextInsertionProbe
    ) {
        self.settingsStore = settingsStore
        self.sessionAPIKeyStore = sessionAPIKeyStore
        self.persistentAPIKeyStore = persistentAPIKeyStore
        self.permissionService = permissionService
        self.sessionLogStore = sessionLogStore
        self.triggerEngine = triggerEngine
        self.recordingEngine = recordingEngine
        self.asrService = asrService
        self.cleanupService = cleanupService
        self.contextInspector = contextInspector
        self.textInserter = textInserter
        self.hudController = hudController
        self.orchestrator = orchestrator
        self.fixedTextInsertionProbe = fixedTextInsertionProbe
    }
}
