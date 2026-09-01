import Cocoa
import SwiftUI

extension Notification.Name {
    static let draftAidPanelDidShow = Notification.Name("DraftAidPanelDidShow")
}

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var floatingPanel: FloatingPanel!

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pencil.line", accessibilityDescription: "Draft Aid")
            button.action = #selector(togglePanel(_:))
            button.target = self
        }

        floatingPanel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 640, height: 420))
    }

    @objc func togglePanel(_ sender: AnyObject?) {
        if floatingPanel.isVisible {
            floatingPanel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    func showPanel() {
        floatingPanel.center()
        floatingPanel.makeKeyAndOrderFront(nil)
        floatingPanel.focusInput()
        NotificationCenter.default.post(name: .draftAidPanelDidShow, object: nil)
    }

    func hidePanel() {
        floatingPanel.orderOut(nil)
    }
}

// MARK: - Floating Panel
class FloatingPanel: NSPanel {
    private var hostingView: NSHostingView<ContentView>!

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        // Open on the currently active desktop, then stay pinned to it
        // (canJoinAllSpaces would make it follow across every Space)
        self.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isOpaque = false
        // Borderless panel has no title bar — let users drag it by empty areas
        self.isMovableByWindowBackground = true

        // Create the SwiftUI view
        let contentView = ContentView(onDismiss: { [weak self] in
            self?.orderOut(nil)
        })

        hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
    }

    // Borderless + nonactivating panels refuse key status by default;
    // without this the text field can never receive keyboard focus.
    override var canBecomeKey: Bool { true }

    func focusInput() {
        // Find and focus the text field after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.findTextField()?.becomeFirstResponder()
        }
    }

    private func findTextField() -> NSTextField? {
        return findSubview(ofType: NSTextField.self, in: hostingView)
    }

    private func findSubview<T: NSView>(ofType type: T.Type, in view: NSView?) -> T? {
        guard let view = view else { return nil }
        if let typed = view as? T { return typed }
        for subview in view.subviews {
            if let found = findSubview(ofType: type, in: subview) { return found }
        }
        return nil
    }

    // Close on Escape
    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    // Allow click-through if needed, but close when clicking outside
    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow
        if !contentView!.frame.contains(location) {
            orderOut(nil)
        } else {
            super.mouseDown(with: event)
        }
    }
}
