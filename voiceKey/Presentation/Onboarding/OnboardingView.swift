import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @State private var testInput = ""
    @State private var showingAPIKeyHelp = false
    @FocusState private var testFieldFocused: Bool

    private let steps = OnboardingStep.allCases

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.93, blue: 0.88),
                    Color(red: 0.9, green: 0.95, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topBar
                    stepper
                    summaryStrip
                    contentCard
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            viewModel.refreshPermissions()
            viewModel.refreshAPIKeyStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshPermissions()
            viewModel.refreshAPIKeyStatus()
        }
        .onChange(of: viewModel.currentStep) { _, newValue in
            if newValue == .directWrite {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    testFieldFocused = true
                }
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("首次使用引导")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("先完成第一次成功输入，再谈更多设置。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("4 步完成第一次输入")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.62), in: Capsule())
        }
    }

    private var stepper: some View {
        HStack(spacing: 10) {
            ForEach(steps, id: \.rawValue) { step in
                stepPill(step)
            }
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 12) {
            summaryChip(title: "API Key", value: viewModel.apiKeyStatusText)
            summaryChip(title: "麦克风", value: viewModel.permissionStatus.microphone.title)
            summaryChip(title: "写回模式", value: viewModel.writeModeLabel)
        }
    }

    private var contentCard: some View {
        card {
            VStack(alignment: .leading, spacing: 20) {
                header
                currentStepContent
            }
        }
    }

    @ViewBuilder
    private var currentStepContent: some View {
        switch viewModel.currentStep {
        case .welcome:
            welcomeStep
        case .apiKey:
            apiKeyStep
        case .permissions:
            permissionsStep
        case .directWrite:
            directWriteStep
        }
    }

    private var header: some View {
        VStack(alignment: headerAlignment, spacing: viewModel.currentStep == .welcome ? 12 : 10) {
            Text(viewModel.currentStep.progressLabel)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.7), in: Capsule())

            if viewModel.currentStep == .welcome {
                VoiceKeyBrandMark(hero: true)
                    .padding(.vertical, 4)
            }

            Text(viewModel.currentStep.title)
                .font(.system(size: viewModel.currentStep == .welcome ? 38 : 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(viewModel.currentStep == .welcome ? .center : .leading)

            Text(viewModel.currentStep.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(viewModel.currentStep == .welcome ? .center : .leading)

            if let guideMessage = viewModel.guideMessage {
                infoCallout(
                    title: "当前反馈",
                    copy: guideMessage,
                    tint: Color(red: 0.1, green: 0.46, blue: 0.53)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: headerFrameAlignment)
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            infoCallout(
                title: "这次只讲 3 件事",
                copy: "需要百炼 API Key、需要麦克风、辅助功能只影响是否直接写回当前光标。",
                tint: Color(red: 0.8, green: 0.36, blue: 0.14)
            )

            overviewCard(
                title: "这条路径会发生什么",
                body: "欢迎 -> API Key -> 权限准备 -> 直接写入测试。首次引导的目标是让你在 2 分钟内成功写出第一句话。"
            )

            HStack(spacing: 12) {
                Button("开始设置") {
                    viewModel.continueFromWelcome()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())

                Button("稍后配置") {
                    viewModel.finishOnboarding()
                }
                .buttonStyle(OnboardingSecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var apiKeyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            card {
                VStack(alignment: .leading, spacing: 16) {
                    Text("连接百炼 API Key")
                        .font(.headline)

                    Text("先本次使用，跑通后再决定是否保存。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("当前状态")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(viewModel.apiKeyStatusText)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.7), in: Capsule())
                    }

                    SecureField("输入 sk- 开头的 API Key", text: $viewModel.apiKeyInput)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 10) {
                        Button("继续") {
                            viewModel.useAPIKeyForCurrentSession()
                        }
                        .buttonStyle(OnboardingPrimaryButtonStyle())

                        Button("读取已保存 Key") {
                            viewModel.loadSavedAPIKeyIntoCurrentSession()
                        }
                        .buttonStyle(OnboardingSecondaryButtonStyle())
                    }

                    Button("顺手存入安全存储") {
                        viewModel.saveAPIKeyToPersistentStore()
                    }
                    .buttonStyle(OnboardingGhostButtonStyle())

                    DisclosureGroup(isExpanded: $showingAPIKeyHelp) {
                        VStack(alignment: .leading, spacing: 12) {
                            applyStep(title: "1. 登录百炼控制台", body: "先完成账号登录和实名认证。")
                            applyStep(title: "2. 切到华北 2（北京）", body: "当前 app 默认对接北京节点，这一步必须明显。")
                            applyStep(title: "3. 创建 API Key", body: "建议先用默认业务空间 + 全部权限。")
                            applyStep(title: "4. 开启免费额度保护", body: "把“会不会误扣费”的担心提前化解掉。")

                            HStack(spacing: 10) {
                                Button("打开百炼控制台") {
                                    viewModel.openBailianConsole()
                                }
                                .buttonStyle(OnboardingSecondaryButtonStyle())

                                Button("查看 API Key 文档") {
                                    viewModel.openGetAPIKeyDocs()
                                }
                                .buttonStyle(OnboardingGhostButtonStyle())

                                Button("免费额度说明") {
                                    viewModel.openFreeQuotaDocs()
                                }
                                .buttonStyle(OnboardingGhostButtonStyle())
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("还没有 Key？查看申请步骤")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(red: 0.8, green: 0.36, blue: 0.14))
                    }
                    .tint(Color(red: 0.8, green: 0.36, blue: 0.14))
                }
            }
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                microphonePermissionRow
                accessibilityPermissionRow
            }

            Text("麦克风决定能不能录音，辅助功能决定能不能直接写回当前光标。不开辅助功能也能继续，但会使用剪贴板回退。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(permissionsContinueTitle) {
                    viewModel.continueToDirectWriteTest()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .disabled(!viewModel.microphoneReady)

                Button("返回 API Key") {
                    viewModel.move(to: .apiKey)
                }
                .buttonStyle(OnboardingSecondaryButtonStyle())
            }
        }
    }

    private var directWriteStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("当前模式")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    modeBadge
                }

                Text("把光标点进下面，再按 Fn 说一句话。目标不是只验证能不能识别，而是直接确认结果能不能落到当前输入框。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $testInput)
                    .focused($testFieldFocused)
                    .font(.system(size: 15))
                    .frame(minHeight: 220)
                    .padding(10)
                    .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )

                Button("写入测试文本") {
                    testFieldFocused = true
                    viewModel.runWriteTest()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())

                Text("推荐测试句：今天先测试第一句听写。也可以先点“写入测试文本”验证当前光标写回链路。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            overviewCard(
                title: "顺手试一下翻译",
                body: "按住 Fn + Control，可以直接输出翻译结果。它不是首次引导的必经步骤，但适合在第一次成功输入后顺手试一下。"
            )

            HStack(spacing: 12) {
                Button("完成首次引导") {
                    viewModel.finishOnboarding()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())

                Button("返回权限准备") {
                    viewModel.move(to: .permissions)
                }
                .buttonStyle(OnboardingSecondaryButtonStyle())
            }
        }
    }

    private func stepPill(_ step: OnboardingStep) -> some View {
        Button {
            viewModel.move(to: step)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text("\(step.rawValue + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(viewModel.currentStep == step ? Color.white : Color.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        (viewModel.currentStep == step ? Color(red: 0.8, green: 0.36, blue: 0.14) : Color.white.opacity(0.62)),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(step.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(viewModel.currentStep == step ? Color.white.opacity(0.76) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func summaryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.weight(.semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var headerAlignment: HorizontalAlignment {
        viewModel.currentStep == .welcome ? .center : .leading
    }

    private var headerFrameAlignment: Alignment {
        viewModel.currentStep == .welcome ? .center : .leading
    }

    private var permissionsContinueTitle: String {
        if !viewModel.microphoneReady {
            return "先完成麦克风授权"
        }
        return viewModel.accessibilityReady ? "开始直接写入测试" : "继续测试"
    }

    private var modeBadge: some View {
        Text(viewModel.writeModeLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(viewModel.accessibilityReady ? Color.green : Color.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.7), in: Capsule())
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }

    private func infoCallout(title: String, copy: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(copy)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func overviewCard(title: String, body: String) -> some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func applyStep(title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(title.prefix(1)))
                .font(.caption.weight(.bold))
                .frame(width: 32, height: 32)
                .background(Color(red: 0.8, green: 0.36, blue: 0.14).opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(Color(red: 0.8, green: 0.36, blue: 0.14))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func permissionRow(
        title: String,
        subtitle: String,
        state: String,
        primaryTitle: String,
        primaryAction: (() -> Void)?,
        secondaryTitle: String,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(state)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.7), in: Capsule())
            }

            HStack(spacing: 10) {
                if let primaryAction {
                    Button(primaryTitle, action: primaryAction)
                        .buttonStyle(OnboardingPrimaryButtonStyle())
                } else {
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(OnboardingSecondaryButtonStyle())
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var microphonePermissionRow: some View {
        Group {
            if viewModel.microphoneReady {
                permissionRow(
                    title: "麦克风",
                    subtitle: "必须。不开就无法开始语音识别。",
                    state: viewModel.permissionStatus.microphone.title,
                    primaryTitle: "麦克风已就绪",
                    primaryAction: nil,
                    secondaryTitle: "打开系统设置",
                    secondaryAction: viewModel.openMicrophoneSettings
                )
            } else {
                permissionRow(
                    title: "麦克风",
                    subtitle: "必须。不开就无法开始语音识别。",
                    state: viewModel.permissionStatus.microphone.title,
                    primaryTitle: "请求麦克风权限",
                    primaryAction: viewModel.requestMicrophone,
                    secondaryTitle: "打开系统设置",
                    secondaryAction: viewModel.openMicrophoneSettings
                )
            }
        }
    }

    private var accessibilityPermissionRow: some View {
        Group {
            if viewModel.accessibilityReady {
                permissionRow(
                    title: "辅助功能",
                    subtitle: "建议。开了之后，第一次测试直接验证写回光标。",
                    state: viewModel.permissionStatus.accessibility.title,
                    primaryTitle: "辅助功能已就绪",
                    primaryAction: nil,
                    secondaryTitle: "打开系统设置",
                    secondaryAction: viewModel.openAccessibilitySettings
                )
            } else {
                permissionRow(
                    title: "辅助功能",
                    subtitle: "建议。开了之后，第一次测试直接验证写回光标。",
                    state: viewModel.permissionStatus.accessibility.title,
                    primaryTitle: "请求辅助功能",
                    primaryAction: viewModel.requestAccessibility,
                    secondaryTitle: "打开系统设置",
                    secondaryAction: viewModel.openAccessibilitySettings
                )
            }
        }
    }
}

private struct VoiceKeyBrandMark: View {
    let hero: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: hero ? 24 : 16, style: .continuous)
                .fill(Color.black)

            HStack(alignment: .bottom, spacing: hero ? 10 : 6) {
                bar(height: hero ? 42 : 26)
                bar(height: hero ? 54 : 34)
                bar(height: hero ? 64 : 40)
                bar(height: hero ? 54 : 34)
                bar(height: hero ? 42 : 26)
            }
            .frame(height: hero ? 72 : 44)
        }
        .frame(width: hero ? 220 : 126, height: hero ? 92 : 52)
        .shadow(color: Color.black.opacity(hero ? 0.14 : 0.08), radius: hero ? 18 : 10, y: hero ? 10 : 6)
    }

    private func bar(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 999, style: .continuous)
            .fill(Color.white)
            .frame(width: hero ? 12 : 7, height: height)
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.84, green: 0.4, blue: 0.18), Color(red: 0.75, green: 0.3, blue: 0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(configuration.isPressed ? 0.45 : 0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct OnboardingGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white.opacity(configuration.isPressed ? 0.38 : 0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }
}
