import AppKit
import SwiftUI

final class OnboardingWindowController: NSWindowController {
    convenience init<Content: View>(rootView: Content) {
        let controller = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: controller)
        window.title = "\(BuildInfo.displayName) 首次使用"
        window.setContentSize(NSSize(width: 980, height: 760))
        self.init(window: window)
    }
}
