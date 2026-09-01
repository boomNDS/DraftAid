import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController()

        GlobalHotkeyManager.shared.onTrigger = { [weak self] in
            self?.statusBarController.showPanel()
        }
        GlobalHotkeyManager.shared.register()
    }
}
