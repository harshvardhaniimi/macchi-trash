import AppKit

enum DockEdge {
    case left
    case right
    case bottom
}

struct DockGeometry {
    let edge: DockEdge
    let thickness: CGFloat
    let screen: NSScreen

    static func current(screen: NSScreen) -> DockGeometry {
        let frame = screen.frame
        let visible = screen.visibleFrame

        let leftInset = max(0, visible.minX - frame.minX)
        let rightInset = max(0, frame.maxX - visible.maxX)
        let bottomInset = max(0, visible.minY - frame.minY)
        let fallbackEdge: DockEdge
        if leftInset > rightInset && leftInset > bottomInset {
            fallbackEdge = .left
        } else if rightInset > leftInset && rightInset > bottomInset {
            fallbackEdge = .right
        } else {
            fallbackEdge = .bottom
        }

        let preferredEdge = DockPreferences.edge() ?? fallbackEdge
        let inferredThickness: CGFloat
        switch preferredEdge {
        case .left:
            inferredThickness = max(leftInset, 56)
        case .right:
            inferredThickness = max(rightInset, 56)
        case .bottom:
            inferredThickness = max(bottomInset, 56)
        }
        return DockGeometry(edge: preferredEdge, thickness: inferredThickness, screen: screen)
    }

    var dockRect: CGRect {
        let frame = screen.frame
        switch edge {
        case .bottom:
            return CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: thickness)
        case .left:
            return CGRect(x: frame.minX, y: frame.minY, width: thickness, height: frame.height)
        case .right:
            return CGRect(x: frame.maxX - thickness, y: frame.minY, width: thickness, height: frame.height)
        }
    }

    var trashHotZone: CGRect {
        let rect = dockRect
        // Tight zone roughly matching the Trash icon area.
        switch edge {
        case .bottom:
            let zoneWidth: CGFloat = 80
            return CGRect(
                x: rect.maxX - zoneWidth,
                y: rect.minY,
                width: zoneWidth,
                height: rect.height + 10
            )
        case .left:
            let zoneHeight: CGFloat = 80
            return CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width + 10,
                height: zoneHeight
            )
        case .right:
            let zoneHeight: CGFloat = 80
            return CGRect(
                x: rect.maxX - rect.width - 10,
                y: rect.minY,
                width: rect.width + 10,
                height: zoneHeight
            )
        }
    }

    var trashAnchorPoint: CGPoint {
        let zone = trashHotZone
        return CGPoint(x: zone.midX, y: zone.midY)
    }
}

private enum DockPreferences {
    static func edge() -> DockEdge? {
        guard
            let domain = UserDefaults.standard.persistentDomain(forName: "com.apple.dock"),
            let raw = domain["orientation"] as? String
        else {
            return nil
        }

        switch raw {
        case "left":
            return .left
        case "right":
            return .right
        default:
            return .bottom
        }
    }
}
