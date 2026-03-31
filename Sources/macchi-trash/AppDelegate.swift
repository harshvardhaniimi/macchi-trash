import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let trashMonitor = TrashMonitor()
    private let cursorMonitor = CursorTrashProximityMonitor()
    private let overlayController = FlyOverlayController()
    private let anchorStore = TrashAnchorStore()

    private var manualAnchor: CGPoint?
    private var statusBarController: StatusBarController?
    private var cancellables = Set<AnyCancellable>()
    private var calibrationWorkItem: DispatchWorkItem?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func applicationDidFinishLaunching(_ notification: Notification) {
        DockAccessibilityTrashLocator.requestPermissionPromptIfNeeded()

        manualAnchor = anchorStore.load()
        overlayController.setDefaultAnchor(manualAnchor)
        cursorMonitor.setManualAnchor(manualAnchor)

        statusBarController = StatusBarController(
            statusItem: statusItem,
            onCalibrate: { [weak self] in self?.startCalibration() },
            onClearCalibration: { [weak self] in self?.clearCalibration() },
            onRequestAccessibility: { DockAccessibilityTrashLocator.requestPermissionPromptIfNeeded() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
        statusBarController?.setCalibrationEnabled(manualAnchor != nil)

        Publishers.CombineLatest(
            trashMonitor.$hasItems.removeDuplicates(),
            cursorMonitor.$hoverAnchor.removeDuplicates(by: { lhs, rhs in
                switch (lhs, rhs) {
                case (nil, nil):
                    return true
                case let (l?, r?):
                    let dx = l.x - r.x
                    let dy = l.y - r.y
                    return hypot(dx, dy) < 2
                default:
                    return false
                }
            })
        )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasItems, hoverAnchor in
                guard let self else {
                    return
                }
                let isCursorNearTrash = hoverAnchor != nil
                let shouldShow = hasItems && isCursorNearTrash

                let debugInfo = DebugInfo(
                    axTrusted: DockAccessibilityTrashLocator.isTrusted(),
                    detectionTier: cursorMonitor.lastDetectionTier.rawValue,
                    mouseLocation: NSEvent.mouseLocation,
                    hoverAnchor: hoverAnchor,
                    extra: cursorMonitor.lastDebugExtra
                )

                overlayController.setPreferredAnchor(hoverAnchor)
                statusBarController?.update(hasItems: hasItems, cursorNearTrash: isCursorNearTrash, debugInfo: debugInfo)

                if shouldShow {
                    overlayController.show()
                } else {
                    overlayController.hide()
                }
            }
            .store(in: &cancellables)

        trashMonitor.start()
        cursorMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        calibrationWorkItem?.cancel()
        trashMonitor.stop()
        cursorMonitor.stop()
        overlayController.stop()
    }

    private func startCalibration() {
        calibrationWorkItem?.cancel()
        statusBarController?.setCalibrating(true)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            let point = NSEvent.mouseLocation
            manualAnchor = point
            anchorStore.save(point)
            overlayController.setDefaultAnchor(point)
            cursorMonitor.setManualAnchor(point)

            calibrationWorkItem = nil
            statusBarController?.setCalibrating(false)
            statusBarController?.setCalibrationEnabled(true)
        }
        calibrationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5), execute: workItem)
    }

    private func clearCalibration() {
        calibrationWorkItem?.cancel()
        calibrationWorkItem = nil
        manualAnchor = nil
        anchorStore.clear()
        overlayController.setDefaultAnchor(nil)
        cursorMonitor.setManualAnchor(nil)

        statusBarController?.setCalibrating(false)
        statusBarController?.setCalibrationEnabled(false)
    }
}

struct DebugInfo {
    let axTrusted: Bool
    let detectionTier: String
    let mouseLocation: CGPoint
    let hoverAnchor: CGPoint?
    let extra: String
}

@MainActor
final class StatusBarController: NSObject {
    private let onCalibrate: () -> Void
    private let onClearCalibration: () -> Void
    private let onRequestAccessibility: () -> Void
    private let onQuit: () -> Void

    private let statusItem: NSStatusItem
    private let stateItem = NSMenuItem(title: "Trash status: checking...", action: nil, keyEquivalent: "")
    private let debugMenuItem = NSMenuItem(title: "Debug: ...", action: nil, keyEquivalent: "")
    private let debugMenuItem2 = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var clearCalibrationItem: NSMenuItem?
    private var lastHasItems = false
    private var lastCursorNearTrash = false
    private var hasCalibration = false
    private var isCalibrating = false

    init(
        statusItem: NSStatusItem,
        onCalibrate: @escaping () -> Void,
        onClearCalibration: @escaping () -> Void,
        onRequestAccessibility: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.statusItem = statusItem
        self.onCalibrate = onCalibrate
        self.onClearCalibration = onClearCalibration
        self.onRequestAccessibility = onRequestAccessibility
        self.onQuit = onQuit
        super.init()
        configure()
    }

    func update(hasItems: Bool, cursorNearTrash: Bool, debugInfo: DebugInfo? = nil) {
        lastHasItems = hasItems
        lastCursorNearTrash = cursorNearTrash
        refreshStateTitle()
        if let debugInfo {
            let mouse = debugInfo.mouseLocation
            var text = "AX: \(debugInfo.axTrusted ? "trusted" : "NOT trusted") | Tier: \(debugInfo.detectionTier)"
            text += " | Mouse: (\(Int(mouse.x)), \(Int(mouse.y)))"
            if let anchor = debugInfo.hoverAnchor {
                text += " | Anchor: (\(Int(anchor.x)), \(Int(anchor.y)))"
            }
            debugMenuItem.title = text
            debugMenuItem2.title = debugInfo.extra
        }
    }

    func setCalibrating(_ active: Bool) {
        isCalibrating = active
        refreshStateTitle()
    }

    func setCalibrationEnabled(_ enabled: Bool) {
        hasCalibration = enabled
        clearCalibrationItem?.isHidden = !enabled
        refreshStateTitle()
    }

    private func configure() {
        stateItem.isEnabled = false
        debugMenuItem.isEnabled = false
        debugMenuItem2.isEnabled = false

        let menu = NSMenu()
        menu.addItem(stateItem)
        menu.addItem(debugMenuItem)
        menu.addItem(debugMenuItem2)
        menu.addItem(NSMenuItem.separator())

        let calibrateItem = NSMenuItem(title: "Calibrate Trash Position (5s)", action: #selector(calibratePressed), keyEquivalent: "")
        calibrateItem.target = self
        menu.addItem(calibrateItem)

        let clearCalibrationItem = NSMenuItem(title: "Clear Calibration", action: #selector(clearCalibrationPressed), keyEquivalent: "")
        clearCalibrationItem.target = self
        clearCalibrationItem.isHidden = true
        menu.addItem(clearCalibrationItem)
        self.clearCalibrationItem = clearCalibrationItem

        let accessibilityItem = NSMenuItem(title: "Request Accessibility Permission", action: #selector(requestAccessibilityPressed), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Macchi Trash", action: #selector(quitPressed), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Macchi Trash")
        refreshStateTitle()
    }

    private func refreshStateTitle() {
        if isCalibrating {
            stateItem.title = "Calibrating: move cursor over Trash..."
            return
        }

        let base = lastHasItems ? "Trash status: dirty" : "Trash status: clean"
        var parts = [base]
        if lastCursorNearTrash {
            parts.append("cursor near trash")
        }
        if hasCalibration {
            parts.append("calibrated")
        }
        stateItem.title = parts.joined(separator: " • ")
    }

    @objc
    private func calibratePressed() {
        onCalibrate()
    }

    @objc
    private func clearCalibrationPressed() {
        onClearCalibration()
    }

    @objc
    private func requestAccessibilityPressed() {
        onRequestAccessibility()
    }

    @objc
    private func quitPressed() {
        onQuit()
    }
}
