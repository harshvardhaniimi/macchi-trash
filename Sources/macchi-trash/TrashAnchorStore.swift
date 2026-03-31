import AppKit

struct TrashAnchorStore {
    private let xKey = "manualTrashAnchorX"
    private let yKey = "manualTrashAnchorY"
    private let enabledKey = "manualTrashAnchorEnabled"

    func load() -> CGPoint? {
        guard UserDefaults.standard.bool(forKey: enabledKey) else {
            return nil
        }
        let x = UserDefaults.standard.double(forKey: xKey)
        let y = UserDefaults.standard.double(forKey: yKey)
        return CGPoint(x: x, y: y)
    }

    func save(_ point: CGPoint) {
        UserDefaults.standard.set(true, forKey: enabledKey)
        UserDefaults.standard.set(point.x, forKey: xKey)
        UserDefaults.standard.set(point.y, forKey: yKey)
    }

    func clear() {
        UserDefaults.standard.set(false, forKey: enabledKey)
        UserDefaults.standard.removeObject(forKey: xKey)
        UserDefaults.standard.removeObject(forKey: yKey)
    }
}
