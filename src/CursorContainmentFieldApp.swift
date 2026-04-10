import SwiftUI

@main
struct CursorContainmentFieldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: appState.isActive ? "lock.rectangle.fill" : "lock.open.rectangle.fill")
        }
    }
}

class AppState: ObservableObject {
    static let shared = AppState()

    // Defaults to true on first launch
    @Published var isActive: Bool =
        UserDefaults.standard.object(forKey: "isActive") as? Bool ?? true {
        didSet { UserDefaults.standard.set(self.isActive, forKey: "isActive") }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var lastTime: TimeInterval = 0
    var lastDeltaX: CGFloat = 0
    var lastDeltaY: CGFloat = 0
    // Must be retained — if released, the monitor silently stops firing
    var eventMonitor: Any?
    // True while any NSMenu (including our MenuBarExtra) is being tracked.
    // CGWarpMouseCursorPosition conflicts with menu event loops and causes
    // erratic cursor behavior, so we pause containment during tracking.
    var isMenuTracking = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isMenuTracking = true
            self?.resetDeltas()
        }
        NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isMenuTracking = false
            self?.resetDeltas()
        }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] event in
            guard let self = self else { return }
            guard AppState.shared.isActive else { return }
            guard !self.isMenuTracking else { return }

            // Discard stale/replayed events
            if self.lastTime != 0, event.timestamp <= self.lastTime {
                self.resetDeltas()
                return
            }

            // Bail cleanly during display configuration changes
            guard let screen = NSScreen.main else { return }

            let deltaX = event.deltaX - self.lastDeltaX
            let deltaY = event.deltaY - self.lastDeltaY
            let pos = event.locationInWindow.flipped(in: screen)

            // Clamp to full screen bounds with a 1-point inset so the cursor
            // never escapes, using the live screen frame (handles resolution changes)
            let bounds = screen.frame
            let xPoint = clamp(pos.x + deltaX, minValue: bounds.minX + 1, maxValue: bounds.maxX - 1)
            let yPoint = clamp(pos.y + deltaY, minValue: bounds.minY + 1, maxValue: bounds.maxY - 1)

            // Reset accumulated delta when the cursor hits a wall so there's no
            // built-up "spring" force making edges feel sticky on the next move
            self.lastDeltaX = (xPoint == pos.x + deltaX) ? xPoint - pos.x : 0
            self.lastDeltaY = (yPoint == pos.y + deltaY) ? yPoint - pos.y : 0

            CGWarpMouseCursorPosition(CGPoint(x: xPoint, y: yPoint))
            self.lastTime = ProcessInfo.processInfo.systemUptime
        }
    }

    private func resetDeltas() {
        lastDeltaX = 0
        lastDeltaY = 0
        lastTime = 0
    }
}

public func clamp<T: Comparable>(_ value: T, minValue: T, maxValue: T) -> T {
    return min(max(value, minValue), maxValue)
}

extension NSPoint {
    // Takes an explicit screen to avoid force-unwrapping NSScreen.main
    func flipped(in screen: NSScreen) -> NSPoint {
        let y = screen.frame.size.height - self.y
        return NSPoint(x: self.x, y: y)
    }
}
