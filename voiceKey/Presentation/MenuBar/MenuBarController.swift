import AppKit

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let environment: AppEnvironment
    private let menuBuilder = MenuContentBuilder()
    private let onboardingActionTarget: ClosureMenuAction
    private let settingsActionTarget: ClosureMenuAction
    private let insertionProbeActionTarget: ClosureMenuAction
    private var onboardingWindowController: OnboardingWindowController?
    private var settingsWindowController: SettingsWindowController?

    init(environment: AppEnvironment) {
        self.environment = environment
        self.onboardingActionTarget = ClosureMenuAction(targetAction: {})
        self.settingsActionTarget = ClosureMenuAction(targetAction: {})
        self.insertionProbeActionTarget = ClosureMenuAction(targetAction: {})
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onboardingActionTarget.replaceAction { [weak self] in
            self?.openOnboarding()
        }
        self.settingsActionTarget.replaceAction { [weak self] in
            self?.openSettings()
        }
        self.insertionProbeActionTarget.replaceAction { [weak self] in
            self?.environment.fixedTextInsertionProbe.run()
        }

        if let button = statusItem.button {
            button.title = BuildInfo.displayName
        }

        refreshMenu()

        environment.hudController.render(.idle)
    }

    func openOnboarding() {
        let controller = onboardingWindowController ?? OnboardingWindowController(
            rootView: OnboardingView(
                viewModel: OnboardingViewModel(
                    settingsStore: environment.settingsStore,
                    sessionAPIKeyStore: environment.sessionAPIKeyStore,
                    persistentAPIKeyStore: environment.persistentAPIKeyStore,
                    permissionService: environment.permissionService,
                    fixedTextInsertionProbe: environment.fixedTextInsertionProbe,
                    onFinish: { [weak self] in
                        self?.refreshMenu()
                        self?.onboardingWindowController?.close()
                        self?.onboardingWindowController = nil
                        self?.openSettings()
                    }
                )
            )
        )
        onboardingWindowController = controller
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        controller.window?.orderFrontRegardless()
    }

    func openSettings() {
        let controller = settingsWindowController ?? SettingsWindowController(
            rootView: SettingsView(
                viewModel: SettingsViewModel(
                    settingsStore: environment.settingsStore,
                    sessionAPIKeyStore: environment.sessionAPIKeyStore,
                    persistentAPIKeyStore: environment.persistentAPIKeyStore,
                    permissionService: environment.permissionService,
                    applySettings: { [weak self, weak environment] previousSettings, settings in
                        if (previousSettings.triggerKey != settings.triggerKey
                            || previousSettings.translationTriggerKey != settings.translationTriggerKey),
                           let triggerEngine = environment?.triggerEngine as? HybridTriggerEngine {
                            try triggerEngine.updateTriggerConfiguration(
                                dictationKey: settings.triggerKey,
                                translationKey: settings.translationTriggerKey
                            )
                        }
                        if previousSettings.asrMode != settings.asrMode,
                           let liveService = environment?.asrService as? any LiveStreamingASRService {
                            Task {
                                await liveService.cancelLiveTranscription()
                            }
                        }
                        self?.refreshMenu()
                    }
                )
            )
        )
        settingsWindowController = controller
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        controller.window?.orderFrontRegardless()
    }

    private func refreshMenu() {
        let settings = (try? environment.settingsStore.load()) ?? .default
        statusItem.menu = menuBuilder.buildMenu(
            settings: settings,
            onboardingTarget: onboardingActionTarget,
            settingsTarget: settingsActionTarget,
            insertionProbeTarget: insertionProbeActionTarget
        )
    }
}
