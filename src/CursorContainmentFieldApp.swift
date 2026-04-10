import SwiftUI

@main
struct CursorContainmentFieldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: appState.isActive ? "lock.fill" : "lock.open.fill")
        }
    }
}

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isActive: Bool =
        UserDefaults.standard.object(forKey: "isActive") as? Bool ?? true {
        didSet { UserDefaults.standard.set(self.isActive, forKey: "isActive") }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var lastTime: TimeInterval = 0
    var lastDeltaX: CGFloat = 0
    var lastDeltaY: CGFloat = 0
    var eventMonitor: Any?
    var isMenuTracking = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuTracking()
        setupEventMonitor()
    }

    private func setupMenuTracking() {
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
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] event in
            guard let self = self else { return }
            guard AppState.shared.isActive else { return }
            guard !self.isMenuTracking else { return }

            if self.lastTime != 0, event.timestamp <= self.lastTime {
                self.resetDeltas()
                return
            }

            guard let screen = NSScreen.main else { return }

            let deltaX = event.deltaX - self.lastDeltaX
            let deltaY = event.deltaY - self.lastDeltaY
            let pos = event.locationInWindow.flipped(in: screen)

            let bounds = screen.frame
            let xPoint = clamp(pos.x + deltaX, minValue: bounds.minX + 1, maxValue: bounds.maxX - 1)
            let yPoint = clamp(pos.y + deltaY, minValue: bounds.minY + 1, maxValue: bounds.maxY - 1)

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

func clamp<T: Comparable>(_ value: T, minValue: T, maxValue: T) -> T {
    min(max(value, minValue), maxValue)
}

extension NSPoint {
    func flipped(in screen: NSScreen) -> NSPoint {
        NSPoint(x: self.x, y: screen.frame.size.height - self.y)
    }
}
