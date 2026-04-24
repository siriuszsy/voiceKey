import AppKit
import Combine
import Foundation

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case apiKey
    case permissions
    case directWrite

    var title: String {
        switch self {
        case .welcome:
            return "欢迎"
        case .apiKey:
            return "连接百炼 API Key"
        case .permissions:
            return "权限准备"
        case .directWrite:
            return "直接写入测试"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            return "先把第一次输入跑通。"
        case .apiKey:
            return "输入后继续，不需要先研究设置。"
        case .permissions:
            return "把录音和写回要用到的权限准备好。"
        case .directWrite:
            return "直接确认文字能不能落到当前输入框。"
        }
    }

    var progressLabel: String {
        switch self {
        case .welcome:
            return "Step 1 / 4"
        case .apiKey:
            return "Step 2 / 4"
        case .permissions:
            return "Step 3 / 4"
        case .directWrite:
            return "Step 4 / 4"
        }
    }
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var apiKeyInput: String = ""
    @Published private(set) var permissionStatus = SystemPermissionStatus(
        inputMonitoring: .notRequired,
        accessibility: .needsSetup,
        microphone: .needsSetup
    )
    @Published private(set) var apiKeyAvailability: APIKeyAvailability = .unavailable
    @Published private(set) var apiKeyStatusText: String = "当前会话未加载。"
    @Published private(set) var guideMessage: String?

    private let settingsStore: SettingsStore
    private let sessionAPIKeyStore: APIKeyStore
    private let persistentAPIKeyStore: APIKeyStore
    private let permissionService: PermissionService
    private let fixedTextInsertionProbe: FixedTextInsertionProbe
    private let environmentProvider: () -> [String: String]
    private let onFinish: () -> Void

    init(
        settingsStore: SettingsStore,
        sessionAPIKeyStore: APIKeyStore,
        persistentAPIKeyStore: APIKeyStore,
        permissionService: PermissionService,
        fixedTextInsertionProbe: FixedTextInsertionProbe,
        environmentProvider: @escaping () -> [String: String] = { ProcessInfo.processInfo.environment },
        onFinish: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.sessionAPIKeyStore = sessionAPIKeyStore
        self.persistentAPIKeyStore = persistentAPIKeyStore
        self.permissionService = permissionService
        self.fixedTextInsertionProbe = fixedTextInsertionProbe
        self.environmentProvider = environmentProvider
        self.onFinish = onFinish
        refreshPermissions()
        refreshAPIKeyStatus()
    }

    var microphoneReady: Bool {
        permissionStatus.microphone == .granted
    }

    var accessibilityReady: Bool {
        permissionStatus.accessibility == .granted
    }

    var writeModeLabel: String {
        accessibilityReady ? "直接写回光标" : "剪贴板回退"
    }

    func move(to step: OnboardingStep) {
        currentStep = step
    }

    func continueFromWelcome() {
        currentStep = .apiKey
    }

    func useAPIKeyForCurrentSession() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            guideMessage = "先粘贴你的百炼 API Key。"
            return
        }

        do {
            try sessionAPIKeyStore.save(trimmed)
            apiKeyInput = trimmed
            currentStep = .permissions
            refreshAPIKeyStatus()
            guideMessage = "已将 API Key 加载到本次运行。下一步去准备权限。"
        } catch {
            guideMessage = "API Key 加载失败：\(error.localizedDescription)"
        }
    }

    func loadSavedAPIKeyIntoCurrentSession() {
        do {
            let storedValue = try persistentAPIKeyStore.load().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !storedValue.isEmpty else {
                guideMessage = "本机安全存储里没有找到已保存的 API Key。"
                return
            }

            try sessionAPIKeyStore.save(storedValue)
            apiKeyInput = storedValue
            currentStep = .permissions
            refreshAPIKeyStatus()
            guideMessage = "已显式读取本机安全存储中的 API Key。"
        } catch {
            guideMessage = "读取已保存 Key 失败：\(error.localizedDescription)"
        }
    }

    func saveAPIKeyToPersistentStore() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            guideMessage = "先粘贴你的百炼 API Key。"
            return
        }

        do {
            try persistentAPIKeyStore.save(trimmed)
            try sessionAPIKeyStore.save(trimmed)
            apiKeyInput = trimmed
            refreshAPIKeyStatus()
            guideMessage = "已存入本机安全存储，本次运行也已加载。"
        } catch {
            guideMessage = "保存到安全存储失败：\(error.localizedDescription)"
        }
    }

    func openBailianConsole() {
        openExternalURL("https://bailian.console.aliyun.com", successMessage: "已打开百炼控制台。拿到 Key 后回到这里继续。")
    }

    func openGetAPIKeyDocs() {
        openExternalURL("https://help.aliyun.com/zh/model-studio/get-api-key", successMessage: "已打开阿里云百炼 API Key 文档。")
    }

    func openFreeQuotaDocs() {
        openExternalURL("https://help.aliyun.com/zh/model-studio/new-free-quota", successMessage: "已打开免费额度说明。")
    }

    func requestMicrophone() {
        permissionService.requestMicrophoneAccess { [weak self] granted in
            Task { @MainActor in
                self?.refreshPermissions()
                self?.guideMessage = granted ? "麦克风权限已准备好。" : "如果你之前点过拒绝，现在要去系统设置里重新打开。"
            }
        }
    }

    func requestAccessibility() {
        _ = permissionService.requestAccessibilityAccess()
        refreshPermissions()
        guideMessage = accessibilityReady
            ? "辅助功能已准备好。"
            : "已经帮你打开授权请求；如果系统没直接生效，请到系统设置里手动打开。"
    }

    func openMicrophoneSettings() {
        if permissionService.openSystemSettings(for: .microphone) {
            guideMessage = "已打开系统设置的麦克风页。"
        } else {
            guideMessage = "没能直接打开系统设置，请手动进入“隐私与安全性 > 麦克风”。"
        }
    }

    func openAccessibilitySettings() {
        if permissionService.openSystemSettings(for: .accessibility) {
            guideMessage = "已打开系统设置的辅助功能页。"
        } else {
            guideMessage = "没能直接打开系统设置，请手动进入“隐私与安全性 > 辅助功能”。"
        }
    }

    func continueToDirectWriteTest() {
        currentStep = .directWrite
        guideMessage = accessibilityReady
            ? "现在可以直接测试写回光标。"
            : "现在也可以测试，但当前会明确走剪贴板回退。"
    }

    func runWriteTest() {
        fixedTextInsertionProbe.run()
        guideMessage = accessibilityReady
            ? "已经发起写入测试。当前应直接写回光标。"
            : "已经发起写入测试。当前会优先走剪贴板回退。"
    }

    func finishOnboarding() {
        var settings = (try? settingsStore.load()) ?? .default
        settings.hasCompletedOnboarding = true

        do {
            try settingsStore.save(settings)
            guideMessage = "首次引导已完成。"
            onFinish()
        } catch {
            guideMessage = "保存首次引导状态失败：\(error.localizedDescription)"
        }
    }

    func refreshPermissions() {
        permissionStatus = permissionService.currentStatus()
    }

    func refreshAPIKeyStatus() {
        if let environmentValue = environmentProvider()["DASHSCOPE_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !environmentValue.isEmpty {
            apiKeyInput = environmentValue
            apiKeyAvailability = .environmentProvided
            apiKeyStatusText = "当前由环境变量提供 API Key。"
            return
        }

        do {
            let sessionValue = try sessionAPIKeyStore.load().trimmingCharacters(in: .whitespacesAndNewlines)
            if !sessionValue.isEmpty {
                apiKeyInput = sessionValue
                apiKeyAvailability = .sessionLoaded
                apiKeyStatusText = "当前会话已加载 API Key。"
                return
            }
        } catch {
            // Session cache is intentionally optional.
        }

        if persistentAPIKeyStore.hasStoredKey() {
            apiKeyAvailability = .persistedButNotLoaded
            apiKeyStatusText = "本机安全存储中已保存 API Key，当前会话未加载。"
            return
        }

        apiKeyAvailability = .unavailable
        apiKeyStatusText = "当前会话未加载 API Key。"
    }

    private func openExternalURL(_ value: String, successMessage: String) {
        guard let url = URL(string: value) else {
            guideMessage = "链接地址无效。"
            return
        }

        if NSWorkspace.shared.open(url) {
            guideMessage = successMessage
        } else {
            guideMessage = "没能打开外部链接，请稍后重试。"
        }
    }
}
