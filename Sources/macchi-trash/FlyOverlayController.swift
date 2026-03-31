import AppKit
import SwiftUI

@MainActor
final class FlyOverlayController {
    private let overlaySize = CGSize(width: FlyOverlayView.viewSize, height: FlyOverlayView.viewSize)
    private var panel: NSPanel?
    private var repositionTimer: Timer?
    private var preferredAnchor: CGPoint?
    private var defaultAnchor: CGPoint?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenLayoutChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show() {
        ensurePanel()
        repositionOverlay()
        panel?.orderFrontRegardless()
        startRepositionTimer()
    }

    func hide() {
        panel?.orderOut(nil)
        repositionTimer?.invalidate()
        repositionTimer = nil
    }

    func stop() {
        hide()
        panel?.close()
        panel = nil
    }

    func setPreferredAnchor(_ point: CGPoint?) {
        preferredAnchor = point
        repositionOverlay()
    }

    func setDefaultAnchor(_ point: CGPoint?) {
        defaultAnchor = point
        repositionOverlay()
    }

    @objc
    private func screenLayoutChanged() {
        repositionOverlay()
    }

    private func ensurePanel() {
        guard panel == nil else {
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: overlaySize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false

        panel.contentView = NSHostingView(rootView: FlyOverlayView())
        self.panel = panel
    }

    private func startRepositionTimer() {
        guard repositionTimer == nil else {
            return
        }

        repositionTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(repositionTimerTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(repositionTimer!, forMode: .common)
    }

    @objc
    private func repositionTimerTick() {
        repositionOverlay()
    }

    private func repositionOverlay() {
        guard let panel, let screen = preferredScreen() else {
            return
        }

        let anchor = preferredAnchor
            ?? defaultAnchor
            ?? DockAccessibilityTrashLocator.currentAnchorPoint()
            ?? DockGeometry.current(screen: screen).trashAnchorPoint
        let origin = CGPoint(x: anchor.x - (overlaySize.width * 0.5), y: anchor.y - (overlaySize.height * 0.5))
        panel.setFrameOrigin(origin)
    }

    private func preferredScreen() -> NSScreen? {
        if let preferredAnchor, let screen = NSScreen.screens.first(where: { $0.frame.contains(preferredAnchor) }) {
            return screen
        }
        if let defaultAnchor, let screen = NSScreen.screens.first(where: { $0.frame.contains(defaultAnchor) }) {
            return screen
        }
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return screen
        }
        if let screen = NSScreen.main {
            return screen
        }
        return NSScreen.screens.first
    }
}
