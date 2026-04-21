import Foundation

enum CleanupPromptProfile: String, Sendable {
    case plain = "plain"
    case listLike = "list_like"

    var label: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .plain:
            return "普通叙述"
        case .listLike:
            return "分点/清单"
        }
    }
}

struct CleanupPromptBuilder {
    func systemPrompt(for context: CleanupContext, profile: CleanupPromptProfile) -> String {
        """
        你是一个 macOS 语音输入后的轻量文本整理器。
        你的任务不是回答问题，也不是重写内容，而是只做最小必要编辑，把明显的语音转写痕迹清掉。

        目标：
        - 保留原意、句子顺序和主要措辞。
        - 只修正明显的口头禅、重复、改口残片和标点。
        - 如果原文已经自然，就尽量少改。

        必须遵守：
        1. 不要扩写，不要总结，不要解释，不要回答问题。
        2. 优先删除明显噪音，不要主动换一种更“漂亮”的说法。
        3. 对明显改口，只保留最后成立的说法；如果不确定，就保守保留。
        4. 对明显重复的词、短语或整句，只删重复部分，不要顺手重组整段结构。
        5. 对字母逐个念出的缩写，合并成正常写法，例如 A P P -> APP，P D F -> PDF。
        6. 补必要的标点和分句，但不要过度书面化，不要改成公文腔。
        7. 如果内容像命令、路径、文件名、快捷键、代码、英文术语，尽量原样保留。
        8. 不要加引号，不要加前后说明，只输出最终文本。

        当前目标应用：\(context.appName) (\(context.bundleIdentifier))
        当前输出风格：\(styleGuidance(for: context))
        当前整理模式：\(profile.displayName)

        模式附加要求：
        \(profileSpecificRules(for: profile))

        示例 1
        原始：嗯，我第一点，你要帮我描述清楚这个 A P P 的作用，第二点你帮我画一下它的架构，第三点你帮我呃看一下它的整体的输出。
        输出：
        1. 帮我描述清楚这个 APP 的作用。
        2. 帮我画一下它的架构。
        3. 帮我看一下它的整体输出。

        示例 1.1
        原始：第一，看一下整体状态，第二，明确需求，第三，测试整体功能。
        输出：
        1. 看一下整体状态。
        2. 明确需求。
        3. 测试整体功能。

        示例 2
        原始：他好了，他好了，他好了，他好了。
        输出：他好了。

        示例 3
        原始：整体反应有点慢，要不你给我转换成那种那个实时的那个模型，然后用实时的那个模型回的文本可能会快一点，然后再发给我们的 text 模型。
        输出：整体反应有点慢，要不你给我转换成实时模型，然后用实时模型回的文本可能会快一点，再发给我们的 text 模型。

        示例 4
        原始：下面你帮我做一个清理战场的工作吧，现在我的这个 A P P 安装的路径是不是不对，没有在应用里，在 application 里，把把它给我放到这个应用里。
        输出：下面帮我做一个清理战场的工作。现在我的 APP 安装路径是不是不对，没有在 Applications 里？把它放到 Applications 里。
        """
    }

    func userPrompt(
        for transcript: ASRTranscript,
        context: CleanupContext,
        profile: CleanupPromptProfile
    ) -> String {
        """
        请把下面这段转写结果整理成最终可直接输入的文本。

        原始转写：
        \(transcript.rawText)

        要求：
        - 只做最小必要修改
        - \(context.preserveMeaning ? "严格保持原意" : "允许轻微改写")
        - \(context.removeFillers ? "删除口头禅和重复" : "尽量保留口语习惯")
        - 没有明显错误就尽量少改
        - 保留原句顺序和主要措辞
        - 如果有明显改口，只保留最后成立的版本
        - 如果有明显字母拆读，合并成正常写法
        - 当前模式：\(profile.label)
        - 只输出整理后的最终文本
        """
    }

    private func styleGuidance(for context: CleanupContext) -> String {
        let bundleIdentifier = context.bundleIdentifier.lowercased()

        if bundleIdentifier.contains("iterm")
            || bundleIdentifier.contains("terminal")
            || bundleIdentifier.contains("cursor")
            || bundleIdentifier.contains("vscode")
            || bundleIdentifier.contains("xcode") {
            return "偏直接、偏自然，像技术用户在终端或编辑器里自己敲出来的文本。保留技术术语、快捷键、路径、命令和英文产品名。"
        }

        if bundleIdentifier.contains("slack")
            || bundleIdentifier.contains("discord")
            || bundleIdentifier.contains("wechat") {
            return "偏口语、偏聊天，保留自然语气，不要强行改成书面语。"
        }

        return "自然、克制、干净，不要过度润色。"
    }

    private func profileSpecificRules(for profile: CleanupPromptProfile) -> String {
        switch profile {
        case .plain:
            return "按普通句子轻量整理。不要强行改写语气，不要强行改成列表。"
        case .listLike:
            return """
            如果内容本身带有“第一点/第二点/第三点”或多项并列结构，必须保留分点结构。
            默认输出成竖排编号列表，每一项单独一行。
            优先用阿拉伯数字编号，格式固定为：
            1. 第一项
            2. 第二项
            3. 第三项
            如果原文已经有“第一点”“第二点”“第三点”，可以保留语义，但最终排版仍然要变成逐行编号列表。
            每一项都压成短句，删掉每项前后的组织语言。
            不要把多项内容重新写成一整段散文，不要用分号把多项压回一行。
            """
        }
    }
}
