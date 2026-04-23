import XCTest
@testable import voiceKey

final class JSONSettingsStoreTests: XCTestCase {
    func testLegacySettingsDefaultToOfflineASRMode() throws {
        let legacyJSON = """
        {
          "triggerKey": "commandSemicolon",
          "microphoneDeviceID": "system-default",
          "cleanupEnabled": true,
          "showHUD": true,
          "fallbackPasteEnabled": true
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: legacyJSON)

        XCTAssertEqual(settings.asrMode, .offline)
        XCTAssertEqual(settings.cleanupModel, "qwen-flash")
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.triggerKey, .fn)
        XCTAssertEqual(settings.translationTriggerKey, .fnControl)
        XCTAssertEqual(settings.translationSourceLanguage, "auto")
        XCTAssertEqual(settings.translationTargetLanguage, "English")
    }

    func testDefaultSettingsUseFnHotkeys() {
        XCTAssertEqual(
            AppSettings.default,
            AppSettings(
                hasCompletedOnboarding: false,
                triggerKey: .fn,
                translationTriggerKey: .fnControl,
                microphoneDeviceID: "system-default",
                asrMode: .offline,
                cleanupModel: "qwen-flash",
                cleanupEnabled: true,
                showHUD: true,
                fallbackPasteEnabled: true,
                translationSourceLanguage: "auto",
                translationTargetLanguage: "English"
            )
        )
    }

    func testUnsupportedTranslationTriggerFallsBackToFnControl() throws {
        let json = """
        {
          "triggerKey": "commandSemicolon",
          "translationTriggerKey": "rightOption"
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(settings.triggerKey, .fn)
        XCTAssertEqual(settings.translationTriggerKey, .fnControl)
    }

    func testTranslationIntentUsesSelectedTriggerDisplayName() {
        XCTAssertEqual(
            SessionIntent.translation.triggerDisplayName(
                dictationTriggerKey: .fn,
                translationTriggerKey: .fnControl
            ),
            TriggerKey.fnControl.displayName
        )
    }
}
