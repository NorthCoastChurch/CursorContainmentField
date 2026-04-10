import SwiftUI

@main
struct CursorContainmentFieldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: appState.isActive ? "cursorarrow.rays" : "cursorarrow")
        }
        .menuBarExtraStyle(.menu)

        Window("Settings", id: "settings") {
            SettingsView(appState: appState)
        }
        .windowResizability(.contentSize)
    }
}

class AppState: ObservableObject {
    static let shared = AppState()

    // Always starts disabled — not persisted across launches.
    @Published var isActive: Bool = false

    // Bundle IDs of apps that should auto-trigger containment.
    @Published var triggerApps: [String] {
        didSet { UserDefaults.standard.set(triggerApps, forKey: "triggerApps") }
    }

    init() {
        triggerApps = UserDefaults.standard.stringArray(forKey: "triggerApps") ?? []
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var containmentTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupContainmentTimer()
        setupAppMonitoring()
    }

    private func setupContainmentTimer() {
        containmentTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0,
            repeats: true
        ) { _ in
            guard AppState.shared.isActive else { return }
            guard let screen = NSScreen.main else { return }

            let loc = NSEvent.mouseLocation
            let x = loc.x
            let y = screen.frame.height - loc.y

            let menuBarH = screen.frame.maxY - screen.visibleFrame.maxY

            // Cursor escaped above the screen — snap back into the menu bar strip.
            if y < 0 {
                let cx = clamp(x, minValue: 1.0, maxValue: screen.frame.width - 1.0)
                CGWarpMouseCursorPosition(CGPoint(x: cx, y: 1.0))
                return
            }

            // Leave the menu bar strip free so the icon stays reachable.
            guard y > menuBarH else { return }

            let cx = clamp(x, minValue: 1.0, maxValue: screen.frame.width - 1.0)
            let cy = clamp(y, minValue: menuBarH, maxValue: screen.frame.height - 1.0)

            if cx != x || cy != y {
                CGWarpMouseCursorPosition(CGPoint(x: cx, y: cy))
            }
        }
    }

    private func setupAppMonitoring() {
        let nc = NSWorkspace.shared.notificationCenter

        // Enable containment when a trigger app launches.
        nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier else { return }
            if AppState.shared.triggerApps.contains(id) {
                AppState.shared.isActive = true
            }
        }

        // Disable containment when a trigger app quits (if no others are still running).
        nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier else { return }
            guard AppState.shared.triggerApps.contains(id) else { return }
            let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
            if !AppState.shared.triggerApps.contains(where: running.contains) {
                AppState.shared.isActive = false
            }
        }

        // If a trigger app is already running when we launch, enable immediately.
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        if AppState.shared.triggerApps.contains(where: running.contains) {
            AppState.shared.isActive = true
        }
    }
}

func clamp<T: Comparable>(_ value: T, minValue: T, maxValue: T) -> T {
    min(max(value, minValue), maxValue)
}
