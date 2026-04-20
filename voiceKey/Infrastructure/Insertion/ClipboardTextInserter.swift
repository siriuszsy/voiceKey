import AppKit
import Foundation
import OSLog

final class ClipboardTextInserter: TextInserter {
    private let logger = Logger(subsystem: BuildInfo.bundleIdentifier, category: "Insertion")

    func insert(
        _ text: String,
        into context: FocusedContext
    ) throws -> InsertionResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard pasteboard.setString(text, forType: .string) else {
            logger.error("Clipboard copy failed. targetApp=\(context.applicationName, privacy: .public)")
            return InsertionResult(
                success: false,
                usedFallback: false,
                failureReason: "无法把结果复制到剪贴板。"
            )
        }

        logger.notice("Copied result to clipboard. targetApp=\(context.applicationName, privacy: .public)")
        return InsertionResult(
            success: true,
            usedFallback: true,
            failureReason: nil
        )
    }
}
