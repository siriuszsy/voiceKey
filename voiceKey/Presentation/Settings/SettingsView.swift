import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    private let overviewColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.93, blue: 0.88),
                    Color(red: 0.91, green: 0.95, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    overviewGrid
                    permissionsCard
                    serviceCard
                    behaviorCard
                    actionCard
                }
                .padding(24)
            }
        }
        .frame(width: 640, height: 720)
        .onAppear {
            viewModel.refreshPermissions()
            viewModel.refreshAPIKeyStatus()
        }
        .onChange(of: viewModel.settings.triggerKey) { _, newValue in
            if viewModel.settings.translationTriggerKey == newValue {
                viewModel.settings.translationTriggerKey = viewModel.availableTranslationTriggerKeys.first ?? .fnShift
            }
        }
        .onChange(of: viewModel.settings.asrMode) { _, _ in
            DispatchQueue.main.async {
                viewModel.applyASRModeChange()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshPermissions()
            viewModel.refreshAPIKeyStatus()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(BuildInfo.displayName)
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text("按住说话，松开落字。设置页只保留真正影响体验的内容。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("本地直写版")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.62), in: Capsule())
            }

            HStack(spacing: 10) {
                heroPill(
                    title: "API Key",
                    value: apiKeySummary,
                    tint: apiKeyReady ? Color.green : Color.orange
                )
                heroPill(
                    title: "麦克风",
                    value: viewModel.permissionStatus.microphone.title,
                    tint: permissionColor(for: viewModel.permissionStatus.microphone)
                )
                heroPill(
                    title: "识别",
                    value: viewModel.settings.asrMode.displayName,
                    tint: Color(red: 0.09, green: 0.46, blue: 0.53)
                )
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.74),
                    Color(red: 0.99, green: 0.97, blue: 0.93).opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var overviewGrid: some View {
        LazyVGrid(columns: overviewColumns, spacing: 12) {
            overviewTile(
                title: "听写触发",
                value: viewModel.triggerKeyDisplayName,
                caption: "当前用于唤起录音的全局快捷键。"
            )
            overviewTile(
                title: "翻译触发",
                value: viewModel.translationTriggerKeyDisplayName,
                caption: "当前用于翻译模式的触发键。"
            )
            overviewTile(
                title: "输入设备",
                value: viewModel.microphoneDisplayName,
                caption: "当前仍使用系统默认输入。"
            )
            overviewTile(
                title: "文本整理",
                value: viewModel.settings.cleanupEnabled ? "已开启" : "已关闭",
                caption: "关闭后会直接输出原始转写结果。"
            )
            overviewTile(
                title: "结果输出",
                value: "自适应输出",
                caption: "有辅助功能时优先直写；没授权时自动回退到剪贴板。"
            )
        }
    }

    private var permissionsCard: some View {
        settingsCard(
            title: "必要权限",
            subtitle: "麦克风决定能不能录，辅助功能决定是直接落字还是先回退到剪贴板。Fn 热键默认直接尝试注册。"
        ) {
            permissionRow(
                title: "辅助功能",
                subtitle: "授权后会优先直接写回当前输入框；没授权时仍可回退到剪贴板。",
                state: viewModel.accessibilityState,
                primaryButtonTitle: "请求授权",
                primaryAction: viewModel.requestAccessibility,
                secondaryButtonTitle: "打开系统设置",
                secondaryAction: viewModel.openAccessibilitySettings
            )

            permissionRow(
                title: "麦克风",
                subtitle: "决定能不能开始录音。没有它，语音识别链路根本不会启动。",
                state: viewModel.permissionStatus.microphone,
                primaryButtonTitle: "请求授权",
                primaryAction: viewModel.requestMicrophone,
                secondaryButtonTitle: "打开系统设置",
                secondaryAction: viewModel.openMicrophoneSettings
            )

            inlineNote(viewModel.permissionHintText)
            inlineNote("如果你的机器上 `Fn` 热键始终收不到，再去“系统设置 > 隐私与安全性 > 键盘监听”里手动打开。")

            if let setupMessage = viewModel.setupMessage {
                inlineNote(setupMessage)
            }
        }
    }

    private var serviceCard: some View {
        settingsCard(
            title: "识别与整理",
            subtitle: "这里决定语音如何变成文字。默认仍然偏稳，不偏花哨。"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("百炼 API Key")
                    .font(.body.weight(.semibold))

                SecureField("输入 sk- 开头的 API Key", text: $viewModel.apiKeyInput)
                    .textFieldStyle(.roundedBorder)

                HStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: apiKeyIconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(apiKeyAccentColor)
                            .frame(width: 26, height: 26)
                            .background(apiKeyAccentColor.opacity(0.14), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text("安全读取默认关闭")
                                .font(.subheadline.weight(.semibold))

                            Text(viewModel.apiKeyStatusText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(14)
                .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(spacing: 8) {
                    apiKeyActionChip(
                        title: "本次使用",
                        systemImage: "bolt.badge.clock",
                        action: viewModel.useAPIKeyForCurrentSession
                    )
                    apiKeyActionChip(
                        title: "存入安全存储",
                        systemImage: "lock",
                        action: viewModel.saveAPIKeyToPersistentStore
                    )
                    apiKeyActionChip(
                        title: "读取已保存 Key",
                        systemImage: "lock.open",
                        action: viewModel.loadSavedAPIKeyIntoCurrentSession
                    )
                }

                inlineNote("默认不会自动读取你的钥匙串。只有你手动点“读取已保存 Key”时，系统才可能要求 Touch ID 或密码。")
            }
            .padding(16)
            .background(cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            asrModeRow

            VStack(alignment: .leading, spacing: 12) {
                toggleRow(
                    title: "启用文本整理",
                    subtitle: "开启后，会去掉重复、口头禅和基础噪音，让结果更像你手打出来的。",
                    isOn: $viewModel.settings.cleanupEnabled
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("整理模型")
                        .font(.body.weight(.semibold))

                    TextField("qwen-flash", text: $viewModel.settings.cleanupModel)
                        .textFieldStyle(.roundedBorder)

                    inlineNote("直接填写真实模型名。当前默认值是 qwen-flash。")
                }
            }
            .padding(16)
            .background(cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Text("翻译设置")
                    .font(.body.weight(.semibold))

                TextField("源语言，默认 auto", text: $viewModel.settings.translationSourceLanguage)
                    .textFieldStyle(.roundedBorder)

                TextField("目标语言，默认 English", text: $viewModel.settings.translationTargetLanguage)
                    .textFieldStyle(.roundedBorder)

                inlineNote("当前翻译触发键是 \(viewModel.translationTriggerKeyDisplayName)。默认方案是 `Fn` 听写，`Fn + Control` 翻译，`Fn + Shift` 留作备选。源语言可填 auto，目标语言建议填写 English、Chinese、Japanese 或对应语言代码。")
            }
            .padding(16)
            .background(cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var behaviorCard: some View {
        settingsCard(
            title: "界面与写回",
            subtitle: "尽量少开关，只保留会明显改变主观体验的行为。"
        ) {
            triggerPickerRow(
                title: "听写触发",
                subtitle: "默认建议用 `Fn`。如果你想把主键位留给翻译，也可以切到 `Fn + Shift` 或 `Fn + Control`。",
                selection: $viewModel.settings.triggerKey,
                choices: TriggerKey.dictationChoices
            )

            triggerPickerRow(
                title: "翻译触发",
                subtitle: "默认建议用 `Fn + Control`。系统会自动避免和听写键冲突，剩下的 `Fn + Shift` 可作备选。",
                selection: $viewModel.settings.translationTriggerKey,
                choices: viewModel.availableTranslationTriggerKeys
            )

            detailRow(
                title: "麦克风来源",
                subtitle: "先沿用系统默认输入设备，不在这里扩展复杂的设备管理。",
                value: viewModel.microphoneDisplayName
            )

            toggleRow(
                title: "显示悬浮球",
                subtitle: "按下时显示录音态，松开后显示处理态。关闭后不影响核心能力。",
                isOn: $viewModel.settings.showHUD
            )

            toggleRow(
                title: "启用粘贴回退",
                subtitle: "有辅助功能时，直写失败后允许尝试粘贴回退；没辅助功能时仍会先复制到剪贴板。",
                isOn: $viewModel.settings.fallbackPasteEnabled
            )
        }
    }

    private var actionCard: some View {
        settingsCard(
            title: "保存与恢复",
            subtitle: "设置页不放测试入口。这里只负责保存当前配置，或者恢复到默认值。"
        ) {
            HStack(spacing: 12) {
                Button("恢复默认配置") {
                    viewModel.resetToDefaults()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("保存设置") {
                    viewModel.save()
                }
                .buttonStyle(.borderedProminent)
            }

            if let saveMessage = viewModel.saveMessage {
                inlineNote(saveMessage)
            }
        }
    }

    private func triggerPickerRow(
        title: String,
        subtitle: String,
        selection: Binding<TriggerKey>,
        choices: [TriggerKey]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.body.weight(.semibold))

            Picker(title, selection: selection) {
                ForEach(choices, id: \.self) { key in
                    Text(key.displayName)
                        .tag(key)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            inlineNote(subtitle)
        }
    }

    private var asrModeRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("语音识别模式")
                .font(.body.weight(.semibold))

            Picker("语音识别模式", selection: $viewModel.settings.asrMode) {
                ForEach(ASRMode.allCases, id: \.self) { mode in
                    Text(mode.displayName)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            inlineNote(viewModel.settings.asrMode.settingsSubtitle)
        }
        .padding(16)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func settingsCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                content()
            }
        }
        .padding(20)
        .background(
            Color(nsColor: .windowBackgroundColor).opacity(0.9),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func heroPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.14), in: Capsule())
    }

    private func overviewTile(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.semibold))

            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Color.white.opacity(0.62),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        subtitle: String,
        state: PermissionState,
        primaryButtonTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryButtonTitle: String,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.body.weight(.semibold))

                    Text(state.title)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(permissionColor(for: state).opacity(0.14), in: Capsule())
                }

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                Button(primaryButtonTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)

                Button(secondaryButtonTitle, action: secondaryAction)
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func detailRow(
        title: String,
        subtitle: String,
        value: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text(value)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.72), in: Capsule())
        }
        .padding(16)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func toggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(16)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func inlineNote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func apiKeyActionChip(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.7), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func permissionColor(for state: PermissionState) -> Color {
        switch state {
        case .granted:
            return .green
        case .needsSetup:
            return .orange
        case .notRequired, .later:
            return .secondary
        }
    }

    private var apiKeyReady: Bool {
        switch viewModel.apiKeyAvailability {
        case .sessionLoaded, .environmentProvided:
            return true
        case .persistedButNotLoaded, .unavailable:
            return false
        }
    }

    private var apiKeySummary: String {
        switch viewModel.apiKeyAvailability {
        case .environmentProvided:
            return "环境变量"
        case .sessionLoaded:
            return "本次可用"
        case .persistedButNotLoaded:
            return "已保存"
        case .unavailable:
            return "未加载"
        }
    }

    private var apiKeyIconName: String {
        switch viewModel.apiKeyAvailability {
        case .environmentProvided:
            return "lock.shield.fill"
        case .sessionLoaded:
            return "lock.open.fill"
        case .persistedButNotLoaded:
            return "lock.fill"
        case .unavailable:
            return "lock.fill"
        }
    }

    private var apiKeyAccentColor: Color {
        apiKeyReady ? Color.green : Color.orange
    }

    private var cardFill: Color {
        Color.black.opacity(0.035)
    }
}
