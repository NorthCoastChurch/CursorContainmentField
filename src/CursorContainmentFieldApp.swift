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
        .menuBarExtraStyle(.menu)
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
        ) { [weak self] _ in self?.isMenuTracking = true }

        NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.isMenuTracking = false }
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] event in
            guard let self = self else { return }
            guard AppState.shared.isActive else { return }
            guard !self.isMenuTracking else { return }
            guard let screen = NSScreen.main else { return }

            // Current cursor position in CG coordinates (top-left origin)
            let pos = event.locationInWindow.flipped(in: screen)

            // Leave the menu bar area free so the icon is reachable
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            guard pos.y > menuBarHeight else { return }

            // Clamp to screen bounds — only warp if the cursor is actually outside
            let bounds = screen.frame
            let clampedX = clamp(pos.x, minValue: bounds.minX + 1, maxValue: bounds.maxX - 1)
            let clampedY = clamp(pos.y, minValue: menuBarHeight + 1, maxValue: bounds.maxY - 1)

            if clampedX != pos.x || clampedY != pos.y {
                CGWarpMouseCursorPosition(CGPoint(x: clampedX, y: clampedY))
            }
        }
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
