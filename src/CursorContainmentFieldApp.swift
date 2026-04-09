import SwiftUI

@main
struct CursorContainmentFieldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
    }
}

class AppState: ObservableObject {
    static let shared = AppState()

    // Bundle ID → display name for app-specific activation
    @Published var registeredApps: Dictionary<String, String> =
        UserDefaults.standard.dictionary(forKey: "registeredApps") as? [String: String] ?? [:] {
        didSet { UserDefaults.standard.set(self.registeredApps, forKey: "registeredApps") }
    }

    // Bundle ID → enabled for app-specific activation
    @Published var activeApps: Dictionary<String, Bool> =
        UserDefaults.standard.dictionary(forKey: "activeApps") as? [String: Bool] ?? [:] {
        didSet { UserDefaults.standard.set(self.activeApps, forKey: "activeApps") }
    }

    // Defaults to true on first launch — always contain the cursor
    @Published var alwaysActive: Bool =
        UserDefaults.standard.object(forKey: "alwaysActive") as? Bool ?? true {
        didSet { UserDefaults.standard.set(self.alwaysActive, forKey: "alwaysActive") }
    }

    @Published var width: String = UserDefaults.standard.string(forKey: "width") ?? "1920" {
        didSet { UserDefaults.standard.set(self.width, forKey: "width") }
    }

    @Published var height: String = UserDefaults.standard.string(forKey: "height") ?? "1080" {
        didSet { UserDefaults.standard.set(self.height, forKey: "height") }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var lastTime: TimeInterval = 0
    var lastDeltaX: CGFloat = 0
    var lastDeltaY: CGFloat = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Remove any activeApps entries whose bundle ID is no longer registered
        for key in AppState.shared.activeApps.keys {
            if AppState.shared.registeredApps[key] == nil {
                AppState.shared.activeApps.removeValue(forKey: key)
            }
        }

        NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] event in
            guard let self = self else { return }

            // Discard stale events (replayed events have an earlier timestamp)
            if self.lastTime != 0, event.timestamp <= self.lastTime {
                self.lastDeltaX = 0
                self.lastDeltaY = 0
                return
            }

            // Determine whether containment should be active right now
            let shouldContain: Bool
            if AppState.shared.alwaysActive {
                shouldContain = true
            } else {
                let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
                shouldContain = AppState.shared.activeApps[frontID] == true
            }

            guard shouldContain else { return }

            // Safe screen access — bail cleanly if the display configuration is mid-change
            guard let screen = NSScreen.main else { return }

            let deltaX = event.deltaX - self.lastDeltaX
            let deltaY = event.deltaY - self.lastDeltaY
            let pos = event.locationInWindow.flipped(in: screen)
            let x = pos.x
            let y = pos.y

            let screenSize = screen.frame.size
            let width  = CGFloat(Int(AppState.shared.width)  ?? Int(screenSize.width))
            let height = CGFloat(Int(AppState.shared.height) ?? Int(screenSize.height))

            // Add 1 so the cursor can't sit exactly on the boundary pixel
            let widthCut  = ((screenSize.width  - width)  / 2) + 1
            let heightCut = ((screenSize.height - height) / 2) + 1

            let xPoint = clamp(x + deltaX, minValue: widthCut,  maxValue: screenSize.width  - widthCut)
            let yPoint = clamp(y + deltaY, minValue: heightCut, maxValue: screenSize.height - heightCut)

            self.lastDeltaX = xPoint - x
            self.lastDeltaY = yPoint - y

            CGWarpMouseCursorPosition(CGPoint(x: xPoint, y: yPoint))
            self.lastTime = ProcessInfo.processInfo.systemUptime
        }
    }
}

public func clamp<T: Comparable>(_ value: T, minValue: T, maxValue: T) -> T {
    return min(max(value, minValue), maxValue)
}

extension NSPoint {
    // Takes an explicit screen instead of force-unwrapping NSScreen.main
    func flipped(in screen: NSScreen) -> NSPoint {
        let y = screen.frame.size.height - self.y
        return NSPoint(x: self.x, y: y)
    }
}
