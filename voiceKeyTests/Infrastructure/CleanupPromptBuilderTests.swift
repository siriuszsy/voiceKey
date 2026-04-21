import XCTest
@testable import voiceKey

final class CleanupPromptBuilderTests: XCTestCase {
    func testPlainPromptPrefersMinimalEditing() {
        let builder = CleanupPromptBuilder()
        let context = CleanupContext(
            appName: "iTerm2",
            bundleIdentifier: "com.googlecode.iterm2",
            preserveMeaning: true,
            removeFillers: true
        )

        let systemPrompt = builder.systemPrompt(for: context, profile: .plain)
        let userPrompt = builder.userPrompt(
            for: ASRTranscript(rawText: "你好你好你好", languageCode: "zh"),
            context: context,
            profile: .plain
        )

        XCTAssertTrue(systemPrompt.contains("只做最小必要编辑"))
        XCTAssertTrue(systemPrompt.contains("不要主动换一种更“漂亮”的说法"))
        XCTAssertTrue(userPrompt.contains("没有明显错误就尽量少改"))
    }

    func testListPromptKeepsStructuredOutput() {
        let builder = CleanupPromptBuilder()
        let context = CleanupContext(
            appName: "Notes",
            bundleIdentifier: "com.apple.Notes",
            preserveMeaning: true,
            removeFillers: true
        )

        let systemPrompt = builder.systemPrompt(for: context, profile: .listLike)

        XCTAssertTrue(systemPrompt.contains("必须保留分点结构"))
        XCTAssertTrue(systemPrompt.contains("1. 第一项"))
    }

    func testProfileDisplayNamesStayConservative() {
        XCTAssertEqual(CleanupPromptProfile.plain.displayName, "普通叙述")
        XCTAssertEqual(CleanupPromptProfile.listLike.displayName, "分点/清单")
    }
}
