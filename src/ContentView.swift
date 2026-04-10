import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) var openWindow

    var body: some View {
        Text(appState.isActive ? "Containment: On" : "Containment: Off")
            .foregroundStyle(.secondary)

        Divider()

        Button(appState.isActive ? "Disable Containment" : "Enable Containment") {
            appState.isActive.toggle()
        }

        Divider()

        Button("Settings...") {
            openWindow(id: "settings")
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        Divider()

        Button("Quit Cursor Containment Field") {
            NSApplication.shared.terminate(nil)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var showingFilePicker = false
    @State private var showingRunningApps = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Auto-Trigger Apps")
                .font(.headline)

            Text("Containment enables when any of these apps launch and disables when all have quit.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List {
                if appState.triggerApps.isEmpty {
                    Text("No apps configured — add one below to get started.")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(appState.triggerApps, id: \.self) { bundleID in
                        HStack(spacing: 8) {
                            if let icon = appIcon(for: bundleID) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(appDisplayName(for: bundleID))
                                Text(bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove") {
                                appState.triggerApps.removeAll { $0 == bundleID }
                            }
                            .foregroundStyle(.red)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 140)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )

            HStack {
                Spacer()
                Button("Running Apps...") {
                    showingRunningApps = true
                }
                Button("From Disk...") {
                    showingFilePicker = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 400, idealWidth: 420, minHeight: 300)
        .sheet(isPresented: $showingRunningApps) {
            RunningAppsSheet(appState: appState, isPresented: $showingRunningApps)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.application],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                guard let bundle = Bundle(url: url),
                      let id = bundle.bundleIdentifier,
                      !appState.triggerApps.contains(id) else { continue }
                appState.triggerApps.append(id)
            }
        }
    }

    private func appDisplayName(for bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { $0.deletingPathExtension().lastPathComponent }
            ?? bundleID
    }

    private func appIcon(for bundleID: String) -> NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
    }
}

struct RunningAppsSheet: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool

    // Apps installed in /Applications that are running, not already listed, and not us.
    var candidates: [NSRunningApplication] {
        let selfID = Bundle.main.bundleIdentifier ?? ""
        return NSWorkspace.shared.runningApplications
            .filter { app in
                guard let id = app.bundleIdentifier else { return false }
                guard id != selfID else { return false }
                guard !appState.triggerApps.contains(id) else { return false }
                guard let path = app.bundleURL?.path else { return false }
                // Must be a top-level .app in /Applications — not a helper
                // nested inside another bundle (e.g. Foo.app/Contents/…Bar.app).
                return path.hasPrefix("/Applications")
                    && path.hasSuffix(".app")
                    && !path.dropFirst("/Applications".count).contains(".app/")
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Running Apps")
                .font(.headline)
                .padding()

            Divider()

            if candidates.isEmpty {
                Text("No additional apps are currently running.")
                    .foregroundStyle(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                List(candidates, id: \.bundleIdentifier) { app in
                    HStack(spacing: 8) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        Text(app.localizedName ?? app.bundleIdentifier ?? "Unknown")
                        Spacer()
                        Button("Add") {
                            if let id = app.bundleIdentifier {
                                appState.triggerApps.append(id)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { isPresented = false }
                    .buttonStyle(.borderedProminent)
                    .padding()
            }
        }
        .frame(minWidth: 360, minHeight: 300)
    }
}
