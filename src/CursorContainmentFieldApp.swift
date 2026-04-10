import AppKit
import Combine

class AppState {
    static let shared = AppState()

    var isActive: Bool =
        UserDefaults.standard.object(forKey: "isActive") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(self.isActive, forKey: "isActive")
            NotificationCenter.default.post(name: .activeStateChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let activeStateChanged = Notification.Name("activeStateChanged")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: – Status bar
    var statusItem: NSStatusItem?

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(activeStateChanged),
            name: .activeStateChanged,
            object: nil
        )
    }

    // MARK: – Status bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        rebuildMenu()
    }

    @objc private func activeStateChanged() {
        updateStatusIcon()
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

        let statusLabel = NSMenuItem(
            title: AppState.shared.isActive ? "Containment: On" : "Containment: Off",
            action: nil,
            keyEquivalent: ""
        )
        statusLabel.isEnabled = false
        menu.addItem(statusLabel)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: AppState.shared.isActive ? "Disable Containment" : "Enable Containment",
            action: #selector(toggleContainment),
            keyEquivalent: ""
        ))

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit CursorContainmentField",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))

        for item in menu.items { item.target = self }
        statusItem?.menu = menu
    }

    @objc private func toggleContainment() {
        AppState.shared.isActive.toggle()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: – Menu tracking

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
    return min(max(value, minValue), maxValue)
}

extension NSPoint {
    func flipped(in screen: NSScreen) -> NSPoint {
        NSPoint(x: self.x, y: screen.frame.size.height - self.y)
    }
}
