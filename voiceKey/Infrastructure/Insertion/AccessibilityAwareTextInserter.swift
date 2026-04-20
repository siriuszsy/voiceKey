import Foundation

final class AccessibilityAwareTextInserter: TextInserter {
    private let permissionService: PermissionService
    private let accessibilityEnabledInserter: TextInserter
    private let accessibilityDisabledInserter: TextInserter

    init(
        permissionService: PermissionService,
        accessibilityEnabledInserter: TextInserter,
        accessibilityDisabledInserter: TextInserter
    ) {
        self.permissionService = permissionService
        self.accessibilityEnabledInserter = accessibilityEnabledInserter
        self.accessibilityDisabledInserter = accessibilityDisabledInserter
    }

    func insert(
        _ text: String,
        into context: FocusedContext
    ) throws -> InsertionResult {
        if permissionService.currentStatus().accessibility == .granted {
            return try accessibilityEnabledInserter.insert(text, into: context)
        }

        return try accessibilityDisabledInserter.insert(text, into: context)
    }
}
