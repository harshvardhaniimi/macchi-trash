import AppKit
import Combine

enum DetectionTier: String {
    case axExact = "AX exact"
    case manualAnchor = "Manual anchor"
    case fallbackGeometry = "Fallback geometry"
    case none = "None"
}

@MainActor
final class CursorTrashProximityMonitor: ObservableObject {
    @Published private(set) var hoverAnchor: CGPoint?
    @Published private(set) var lastDetectionTier: DetectionTier = .none
    private(set) var lastDebugExtra: String = ""

    private var timer: Timer?
    private var manualAnchor: CGPoint?

    func start() {
        update()
        guard timer == nil else {
            return
        }

        timer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(timerTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setManualAnchor(_ anchor: CGPoint?) {
        manualAnchor = anchor
        update()
    }

    @objc
    private func timerTick() {
        update()
    }

    private func update() {
        let mouseLocation = NSEvent.mouseLocation

        // Best path: exact AX hit on the Trash icon.
        if let exactAnchor = DockAccessibilityTrashLocator.hoverAnchorIfCursorIsOnTrash(mouseLocation) {
            hoverAnchor = exactAnchor
            lastDetectionTier = .axExact
            lastDebugExtra = "AX exact hit"
            return
        }

        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            hoverAnchor = nil
            lastDetectionTier = .none
            lastDebugExtra = "No screen found for mouse"
            return
        }

        let geometry = DockGeometry.current(screen: screen)
        let band = max(geometry.thickness + 20, 80)
        let nearDockEdge = isNearDockEdge(mouseLocation, geometry: geometry, screen: screen)

        let edgeStr = "edge:\(geometry.edge) thick:\(Int(geometry.thickness)) band:\(Int(band)) near:\(nearDockEdge)"

        if let manualAnchor {
            let dx = mouseLocation.x - manualAnchor.x
            let dy = mouseLocation.y - manualAnchor.y
            let distance = hypot(dx, dy)
            let matched = nearDockEdge && distance < 50
            hoverAnchor = matched ? manualAnchor : nil
            lastDetectionTier = matched ? .manualAnchor : .none
            lastDebugExtra = "\(edgeStr) | cal:(\(Int(manualAnchor.x)),\(Int(manualAnchor.y))) dist:\(Int(distance))"
            return
        }

        // Fallback: use AX tree scan for Trash frame, with tight proximity check.
        // Only activate when cursor is near the dock edge.
        guard nearDockEdge else {
            hoverAnchor = nil
            lastDetectionTier = .none
            lastDebugExtra = "\(edgeStr) | not near dock"
            return
        }

        if let trashFrame = DockAccessibilityTrashLocator.currentVisibleTrashFrame() {
            let expandedFrame = trashFrame.insetBy(dx: -8, dy: -8)
            if expandedFrame.contains(mouseLocation) {
                let anchor = CGPoint(x: trashFrame.midX, y: trashFrame.midY)
                hoverAnchor = anchor
                lastDetectionTier = .fallbackGeometry
                lastDebugExtra = "\(edgeStr) | AX frame match"
                return
            }
        }

        // Last resort: tight geometric zone, no padding expansion.
        let trashZone = geometry.trashHotZone
        let inZone = trashZone.contains(mouseLocation)
        let zoneStr = "zone:(\(Int(trashZone.minX)),\(Int(trashZone.minY)),\(Int(trashZone.width))x\(Int(trashZone.height)))"
        hoverAnchor = inZone ? geometry.trashAnchorPoint : nil
        lastDetectionTier = inZone ? .fallbackGeometry : .none
        lastDebugExtra = "\(edgeStr) inZone:\(inZone) | \(zoneStr)"
    }

    private func isNearDockEdge(_ mouse: CGPoint, geometry: DockGeometry, screen: NSScreen) -> Bool {
        let band: CGFloat = max(geometry.thickness + 20, 80)
        switch geometry.edge {
        case .bottom:
            return mouse.y <= screen.frame.minY + band
        case .left:
            return mouse.x <= screen.frame.minX + band
        case .right:
            return mouse.x >= screen.frame.maxX - band
        }
    }
}
