import AppKit

struct MenuDebugItem {
    let title: String
    let actionTarget: ClosureMenuAction
}

struct MenuContentBuilder {
    func buildMenu(
        settings: AppSettings,
        onboardingTarget: ClosureMenuAction,
        settingsTarget: ClosureMenuAction,
        insertionProbeTarget: ClosureMenuAction
    ) -> NSMenu {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: BuildInfo.displayName, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        let subtitleItem = NSMenuItem(title: "按住说话，松开落字", action: nil, keyEquivalent: "")
        subtitleItem.isEnabled = false
        menu.addItem(subtitleItem)
        menu.addItem(.separator())

        let onboardingTitle = settings.hasCompletedOnboarding ? "打开首次引导" : "继续首次引导"
        let onboardingItem = NSMenuItem(title: onboardingTitle, action: nil, keyEquivalent: "")
        onboardingItem.target = onboardingTarget
        onboardingItem.action = #selector(ClosureMenuAction.invoke)
        menu.addItem(onboardingItem)

        let settingsItem = NSMenuItem(title: "打开设置", action: nil, keyEquivalent: ",")
        settingsItem.target = settingsTarget
        settingsItem.action = #selector(ClosureMenuAction.invoke)
        menu.addItem(settingsItem)

        let insertionProbeItem = NSMenuItem(title: "写入测试文本", action: nil, keyEquivalent: "")
        insertionProbeItem.target = insertionProbeTarget
        insertionProbeItem.action = #selector(ClosureMenuAction.invoke)
        menu.addItem(insertionProbeItem)

        let dictationTriggerItem = NSMenuItem(
            title: "听写触发：\(settings.triggerKey.displayName)",
            action: nil,
            keyEquivalent: ""
        )
        dictationTriggerItem.isEnabled = false
        menu.addItem(dictationTriggerItem)

        let translationTriggerItem = NSMenuItem(
            title: "翻译触发：\(settings.translationTriggerKey.displayName)",
            action: nil,
            keyEquivalent: ""
        )
        translationTriggerItem.isEnabled = false
        menu.addItem(translationTriggerItem)

        let modeItem = NSMenuItem(
            title: "识别模式：\(settings.asrMode.displayName)",
            action: nil,
            keyEquivalent: ""
        )
        modeItem.isEnabled = false
        menu.addItem(modeItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 \(BuildInfo.displayName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }
}

final class ClosureMenuAction: NSObject {
    private var targetAction: () -> Void

    init(targetAction: @escaping () -> Void) {
        self.targetAction = targetAction
    }

    func replaceAction(_ action: @escaping () -> Void) {
        targetAction = action
    }

    @objc func invoke() {
        targetAction()
    }
}
