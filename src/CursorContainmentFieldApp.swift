import SwiftUI
import os

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
        didSet {
            UserDefaults.standard.set(triggerApps, forKey: "triggerApps")
            applyTriggerChange(from: oldValue)
        }
    }

    // Treat a running app being added as a launch and a running app being
    // removed as a quit, so edits take effect without relaunching anything.
    private func applyTriggerChange(from oldValue: [String]) {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let added = triggerApps.filter { !oldValue.contains($0) }
        let removed = oldValue.filter { !triggerApps.contains($0) }

        if added.contains(where: running.contains) {
            isActive = true
        } else if removed.contains(where: running.contains),
                  !triggerApps.contains(where: running.contains) {
            isActive = false
        }
    }

    init() {
        triggerApps = UserDefaults.standard.stringArray(forKey: "triggerApps") ?? []
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var containmentTimer: Timer?
    private var warpFailing = false
    private let logger = Logger(subsystem: "com.church.CursorContainmentField", category: "containment")

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupContainmentTimer()
        setupAppMonitoring()
    }

    private func setupContainmentTimer() {
        containmentTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0,
            repeats: true
        ) { [weak self] _ in
            guard AppState.shared.isActive else { return }
            // The primary display (the one whose origin is 0,0). NSScreen.main
            // is the screen with the key window, which can be a secondary display.
            guard let screen = NSScreen.screens.first else { return }

            let loc = NSEvent.mouseLocation
            let x = loc.x
            let y = screen.frame.height - loc.y

            let menuBarH = screen.frame.maxY - screen.visibleFrame.maxY

            let cx = clamp(x, minValue: 0.0, maxValue: screen.frame.width - 1.0)

            // Cursor escaped above the screen — snap back to the top row so the
            // menu bar (including an auto-hidden one) stays reachable.
            if y < 0 {
                self?.warp(to: CGPoint(x: cx, y: 0.0))
                return
            }

            // Inside the menu bar strip only the horizontal edges are enforced,
            // so the menu bar stays reachable without leaking onto side displays.
            let cy = y <= menuBarH
                ? y
                : clamp(y, minValue: menuBarH, maxValue: screen.frame.height - 1.0)

            if cx != x || cy != y {
                self?.warp(to: CGPoint(x: cx, y: cy))
            }
        }
    }

    // CGWarpMouseCursorPosition fails silently from the user's point of view,
    // so log the first failure (and recovery) to make an OS-level block visible.
    private func warp(to point: CGPoint) {
        let err = CGWarpMouseCursorPosition(point)
        if err != .success && !warpFailing {
            logger.error("CGWarpMouseCursorPosition failed: \(err.rawValue, privacy: .public)")
        } else if err == .success && warpFailing {
            logger.notice("CGWarpMouseCursorPosition recovered")
        }
        warpFailing = err != .success
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
