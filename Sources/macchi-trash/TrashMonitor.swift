import AppKit
import Combine
import Darwin
import Foundation

@MainActor
final class TrashMonitor: ObservableObject {
    @Published private(set) var hasItems = false

    private let queue = DispatchQueue.main
    private let fileManager = FileManager.default
    private let trashURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)

    private var source: DispatchSourceFileSystemObject?
    private var timer: DispatchSourceTimer?

    func start() {
        refresh()
        startDirectoryWatcher()
        startFallbackPolling()
    }

    func stop() {
        source?.cancel()
        source = nil

        timer?.cancel()
        timer = nil
    }

    private func startDirectoryWatcher() {
        let descriptor = open(trashURL.path, O_EVTONLY)
        guard descriptor >= 0 else {
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .extend, .attrib],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.refresh()
        }

        source.setCancelHandler {
            close(descriptor)
        }

        self.source = source
        source.resume()
    }

    private func startFallbackPolling() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .seconds(5), repeating: .seconds(5))
        timer.setEventHandler { [weak self] in
            self?.refresh()
        }
        self.timer = timer
        timer.resume()
    }

    private func refresh() {
        hasItems = directoryHasItems() || finderTrashHasItems()
    }

    private func directoryHasItems() -> Bool {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: trashURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }
        return entries.contains(where: { !$0.lastPathComponent.hasPrefix(".") })
    }

    private func finderTrashHasItems() -> Bool {
        let script = NSAppleScript(source: """
            tell application "Finder"
                return (count of items of trash) > 0
            end tell
            """)
        var error: NSDictionary?
        guard let result = script?.executeAndReturnError(&error) else {
            return false
        }
        return result.booleanValue
    }
}
