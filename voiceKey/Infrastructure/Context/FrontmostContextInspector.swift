import Foundation

final class FrontmostContextInspector: ContextInspector {
    private let appResolver: FrontmostAppResolver

    init(appResolver: FrontmostAppResolver) {
        self.appResolver = appResolver
    }

    func currentContext() throws -> FocusedContext {
        let app = appResolver.resolve()
        return FocusedContext(
            bundleIdentifier: app.bundleIdentifier,
            applicationName: app.applicationName,
            processIdentifier: app.processIdentifier,
            windowTitle: nil,
            elementRole: nil,
            isEditable: false,
            focusedElement: nil
        )
    }
}
