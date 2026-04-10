import SwiftUI
import Combine

@main
struct CursorContainmentFieldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // All UI is handled by AppDelegate via NSStatusItem —
        // MenuBarExtra had compatibility issues on macOS 26 beta
        Settings { EmptyView() }
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
    // MARK: – Status bar
    var statusItem: NSStatusItem?
    var cancellable: AnyCancellable?

    // MARK: – Cursor containment
    var lastTime: TimeInterval = 0
    var lastDeltaX: CGFloat = 0
    var lastDeltaY: CGFloat = 0
    var eventMonitor: Any?
    var isMenuTracking = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupMenuTracking()
        setupEventMonitor()
    }

    // MARK: – Status bar setup

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()

        // Rebuild the menu each time isActive changes
        cancellable = AppState.shared.$isActive.sink { [weak self] _ in
            self?.updateStatusIcon()
            self?.rebuildMenu()
        }

        rebuildMenu()
    }

    private func updateStatusIcon() {
        let name = AppState.shared.isActive
            ? "lock.rectangle.fill"
            : "lock.open.rectangle.fill"
        statusItem?.button?.image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: "CursorContainmentField"
        )
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let statusTitle = AppState.shared.isActive ? "Containment: On" : "Containment: Off"
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        let toggleTitle = AppState.shared.isActive ? "Disable Containment" : "Enable Containment"
        menu.addItem(NSMenuItem(
            title: toggleTitle,
            action: #selector(toggleContainment),
            keyEquivalent: ""
        ))

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit CursorContainmentField",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))

        // Set target on items that need it
        for item in menu.items { item.target = self }

        self.statusItem?.menu = menu
    }

    @objc private func toggleContainment() {
        AppState.shared.isActive.toggle()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: – Menu tracking (pause containment while menu is open)

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

    // MARK: – Event monitor

    private func setupEventMonitor() {
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

            // Clamp to full screen bounds with a 1-point inset
            let bounds = screen.frame
            let xPoint = clamp(pos.x + deltaX, minValue: bounds.minX + 1, maxValue: bounds.maxX - 1)
            let yPoint = clamp(pos.y + deltaY, minValue: bounds.minY + 1, maxValue: bounds.maxY - 1)

            // Reset accumulated delta when the cursor hits a wall so edges don't feel sticky
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
    func flipped(in screen: NSScreen) -> NSPoint {
        let y = screen.frame.size.height - self.y
        return NSPoint(x: self.x, y: y)
    }
}
