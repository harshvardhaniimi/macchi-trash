import AppKit
import ApplicationServices

enum DockAccessibilityTrashLocator {
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestPermissionPromptIfNeeded() {
        guard !isTrusted() else {
            return
        }
        let key = "AXTrustedCheckOptionPrompt"
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func currentAnchorPoint() -> CGPoint? {
        guard let frame = currentVisibleTrashFrame() else {
            return nil
        }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    static func hoverAnchorIfCursorIsOnTrash(_ point: CGPoint) -> CGPoint? {
        guard isTrusted() else {
            return nil
        }
        guard let hit = dockHitElement(at: point)
        else {
            return nil
        }

        for element in parentChain(startingAt: hit, maxDepth: 12) {
            guard let axFrame = frame(of: element) else { continue }
            let cocoaFrame = axFrameToCocoa(axFrame)
            guard isLikelyVisible(cocoaFrame) else { continue }
            if matchesTrashKeyword(element) {
                return CGPoint(x: cocoaFrame.midX, y: cocoaFrame.midY)
            }
        }

        guard let visibleTrashFrame = currentVisibleTrashFrame() else {
            return nil
        }
        if visibleTrashFrame.insetBy(dx: -6, dy: -6).contains(point) {
            return CGPoint(x: visibleTrashFrame.midX, y: visibleTrashFrame.midY)
        }
        return nil
    }

    static func cursorHitsDockElement(_ point: CGPoint) -> Bool {
        guard isTrusted() else {
            return false
        }
        return dockHitElement(at: point) != nil
    }

    static func currentVisibleTrashFrame() -> CGRect? {
        guard isTrusted() else {
            return nil
        }
        guard let dockPID = dockProcessID() else {
            return nil
        }

        let root = AXUIElementCreateApplication(dockPID)
        let elements = collectElements(from: root)

        if let keywordMatch = elements.first(where: { matchesTrashKeyword($0.element) && isLikelyVisible($0.frame) }) {
            return keywordMatch.frame
        }

        let dockItems = elements.filter { info in
            let role = stringAttribute(of: info.element, kAXRoleAttribute as CFString)?.lowercased() ?? ""
            let subrole = stringAttribute(of: info.element, kAXSubroleAttribute as CFString)?.lowercased() ?? ""
            return role.contains("dockitem") || subrole.contains("dockitem")
        }

        let visibleDockItems = dockItems.filter { isLikelyVisible($0.frame) }
        guard !visibleDockItems.isEmpty else {
            return nil
        }

        let edge = preferredDockEdge()
        let selected: ElementFrame
        switch edge {
        case .bottom:
            selected = visibleDockItems.max(by: { $0.frame.midX < $1.frame.midX })!
        case .left, .right:
            selected = visibleDockItems.min(by: { $0.frame.midY < $1.frame.midY })!
        }

        return selected.frame
    }

    private struct ElementFrame {
        let element: AXUIElement
        let frame: CGRect
    }

    private static func collectElements(from root: AXUIElement) -> [ElementFrame] {
        var result: [ElementFrame] = []
        var stack: [AXUIElement] = [root]
        var visited: Set<UInt> = []

        while let element = stack.popLast(), visited.count < 4000 {
            let hash = CFHash(element)
            if visited.contains(hash) {
                continue
            }
            visited.insert(hash)

            if let axFrame = frame(of: element) {
                let cocoaFrame = axFrameToCocoa(axFrame)
                if cocoaFrame.width > 16, cocoaFrame.height > 16 {
                    result.append(ElementFrame(element: element, frame: cocoaFrame))
                }
            }

            for child in children(of: element) {
                stack.append(child)
            }
        }

        return result
    }

    private static func elementAtScreenPoint(_ point: CGPoint) -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var hitRef: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hitRef)
        guard error == .success else {
            return nil
        }
        return hitRef
    }

    private static func dockHitElement(at point: CGPoint) -> AXUIElement? {
        guard let dockPID = dockProcessID() else {
            return nil
        }
        for candidate in candidatePoints(for: point) {
            if let hit = elementAtScreenPoint(candidate), element(hit, belongsTo: dockPID) {
                return hit
            }
        }
        return nil
    }

    /// Convert Cocoa coordinates (bottom-left origin) to AX/Core Graphics
    /// screen coordinates (top-left origin). The primary screen's height
    /// defines the global coordinate flip.
    private static func cocoaPointToAX(_ cocoaPoint: CGPoint) -> CGPoint {
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: cocoaPoint.x, y: primaryScreenHeight - cocoaPoint.y)
    }

    /// Convert a CGRect from AX screen coordinates (top-left origin) to
    /// Cocoa coordinates (bottom-left origin).
    private static func axFrameToCocoa(_ axFrame: CGRect) -> CGRect {
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let cocoaY = primaryScreenHeight - axFrame.origin.y - axFrame.height
        return CGRect(x: axFrame.origin.x, y: cocoaY, width: axFrame.width, height: axFrame.height)
    }

    private static func candidatePoints(for cocoaPoint: CGPoint) -> [CGPoint] {
        // AXUIElementCopyElementAtPosition expects top-left-origin coordinates.
        // NSEvent.mouseLocation uses bottom-left-origin (Cocoa) coordinates.
        let axPoint = cocoaPointToAX(cocoaPoint)
        if abs(axPoint.y - cocoaPoint.y) > 0.5 {
            return [axPoint, cocoaPoint]
        }
        return [axPoint]
    }

    private static func parentChain(startingAt element: AXUIElement, maxDepth: Int) -> [AXUIElement] {
        var result: [AXUIElement] = [element]
        var current: AXUIElement? = element
        var depth = 0

        while depth < maxDepth {
            guard let currentElement = current,
                  let parentObject = attributeValue(of: currentElement, kAXParentAttribute as CFString)
            else {
                break
            }
            guard CFGetTypeID(parentObject) == AXUIElementGetTypeID() else {
                break
            }
            let parent = parentObject as! AXUIElement
            if CFHash(parent) == CFHash(currentElement) {
                break
            }
            result.append(parent)
            current = parent
            depth += 1
        }

        return result
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        let childAttributes: [CFString] = [
            kAXChildrenAttribute as CFString,
            kAXVisibleChildrenAttribute as CFString,
            kAXContentsAttribute as CFString,
            kAXRowsAttribute as CFString,
            kAXColumnsAttribute as CFString,
        ]

        var output: [AXUIElement] = []
        for attribute in childAttributes {
            guard let value = attributeValue(of: element, attribute),
                  let array = value as? [AnyObject]
            else {
                continue
            }
            for item in array where CFGetTypeID(item) == AXUIElementGetTypeID() {
                output.append(item as! AXUIElement)
            }
        }
        return output
    }

    private static func matchesTrashKeyword(_ element: AXUIElement) -> Bool {
        let keywords = ["trash", "bin", "garbage", "rubbish", "waste"]
        let searchable = [
            stringAttribute(of: element, kAXTitleAttribute as CFString),
            stringAttribute(of: element, kAXDescriptionAttribute as CFString),
            stringAttribute(of: element, kAXValueAttribute as CFString),
            stringAttribute(of: element, "AXURL" as CFString),
            stringAttribute(of: element, "AXIdentifier" as CFString),
        ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        return keywords.contains(where: { searchable.contains($0) })
    }

    private static func preferredDockEdge() -> DockEdge {
        guard let mainScreen = NSScreen.main ?? NSScreen.screens.first else {
            return .bottom
        }
        return DockGeometry.current(screen: mainScreen).edge
    }

    private static func dockProcessID() -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
    }

    private static func element(_ element: AXUIElement, belongsTo pid: pid_t) -> Bool {
        var ownerPID: pid_t = 0
        let error = AXUIElementGetPid(element, &ownerPID)
        return error == .success && ownerPID == pid
    }

    private static func isLikelyVisible(_ frame: CGRect) -> Bool {
        guard frame.width > 0, frame.height > 0 else {
            return false
        }

        let totalArea = frame.width * frame.height
        guard totalArea > 1 else {
            return false
        }

        var visibleArea: CGFloat = 0
        for screen in NSScreen.screens {
            let overlap = frame.intersection(screen.frame)
            if !overlap.isNull, overlap.width > 0, overlap.height > 0 {
                visibleArea += overlap.width * overlap.height
            }
        }
        let ratio = visibleArea / totalArea
        return ratio >= 0.6
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionObject = attributeValue(of: element, kAXPositionAttribute as CFString),
              let sizeObject = attributeValue(of: element, kAXSizeAttribute as CFString) else {
            return nil
        }

        guard CFGetTypeID(positionObject) == AXValueGetTypeID(),
              CFGetTypeID(sizeObject) == AXValueGetTypeID() else {
            return nil
        }

        let positionValue = positionObject as! AXValue
        let sizeValue = sizeObject as! AXValue

        guard
            AXValueGetType(positionValue) == .cgPoint,
            AXValueGetType(sizeValue) == .cgSize
        else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue, .cgPoint, &point)
        AXValueGetValue(sizeValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    private static func attributeValue(of element: AXUIElement, _ attribute: CFString) -> AnyObject? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard error == .success else {
            return nil
        }
        return value as AnyObject?
    }

    private static func stringAttribute(of element: AXUIElement, _ attribute: CFString) -> String? {
        guard let value = attributeValue(of: element, attribute) else {
            return nil
        }
        if let string = value as? String {
            return string
        }
        if let url = value as? URL {
            return url.absoluteString
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }
}
