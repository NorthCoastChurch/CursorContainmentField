import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState
    @State private var newBundleID: String = ""
    @State private var newAppName: String = ""
    @State private var widthError: String? = nil
    @State private var heightError: String? = nil

    // Running regular apps (excludes background agents and our own app)
    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular &&
            $0.bundleIdentifier != Bundle.main.bundleIdentifier &&
            $0.bundleIdentifier != nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            // MARK: Resolution
            Text("Resolution").font(.title2).bold()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Width").font(.caption).foregroundColor(.secondary)
                    TextField("e.g. 1920", text: $appState.width)
                        .onChange(of: appState.width) { _ in validateDimensions() }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Height").font(.caption).foregroundColor(.secondary)
                    TextField("e.g. 1080", text: $appState.height)
                        .onChange(of: appState.height) { _ in validateDimensions() }
                }
            }
            if let error = widthError ?? heightError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Divider()

            // MARK: Activation
            Text("Activation").font(.title2).bold()
            Toggle("Always active (recommended for fixed displays)", isOn: $appState.alwaysActive)

            if !appState.alwaysActive {
                Text("Lock cursor only when one of these apps is in the foreground.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if appState.registeredApps.isEmpty {
                    Text("No apps configured. Add one below.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(
                            appState.registeredApps.sorted(by: { $0.value < $1.value }),
                            id: \.key
                        ) { bundleID, name in
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { appState.activeApps[bundleID] ?? false },
                                    set: { appState.activeApps[bundleID] = $0 }
                                )) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(name)
                                        Text(bundleID)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button(action: { removeApp(bundleID: bundleID) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Divider()

                // MARK: Add App
                Text("Add App").font(.headline)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Display Name").font(.caption).foregroundColor(.secondary)
                        TextField("e.g. ProPresenter", text: $newAppName)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bundle ID").font(.caption).foregroundColor(.secondary)
                        TextField("e.g. com.renewedvision.ProPresenter", text: $newBundleID)
                    }
                }
                HStack(spacing: 8) {
                    Button("Add") { addApp() }
                        .disabled(newBundleID.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  newAppName.trimmingCharacters(in: .whitespaces).isEmpty)

                    // Picker of currently running apps — avoids focus/timing problems
                    // of trying to detect the "previously" frontmost app
                    Menu("Pick Running App") {
                        if runningApps.isEmpty {
                            Text("No running apps found")
                        } else {
                            ForEach(runningApps, id: \.bundleIdentifier) { app in
                                Button(app.localizedName ?? app.bundleIdentifier ?? "Unknown") {
                                    newBundleID = app.bundleIdentifier ?? ""
                                    newAppName  = app.localizedName  ?? ""
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { validateDimensions() }
    }

    // MARK: Helpers

    private func validateDimensions() {
        widthError  = nil
        heightError = nil

        if let w = Int(appState.width) {
            if w <= 0 { widthError = "Width must be greater than zero." }
        } else {
            widthError = "Width must be a whole number (e.g. 1920)."
        }

        if let h = Int(appState.height) {
            if h <= 0 { heightError = "Height must be greater than zero." }
        } else {
            heightError = "Height must be a whole number (e.g. 1080)."
        }
    }

    private func addApp() {
        let id   = newBundleID.trimmingCharacters(in: .whitespaces)
        let name = newAppName.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !name.isEmpty else { return }
        appState.registeredApps[id] = name
        appState.activeApps[id] = true
        newBundleID = ""
        newAppName  = ""
    }

    private func removeApp(bundleID: String) {
        appState.registeredApps.removeValue(forKey: bundleID)
        appState.activeApps.removeValue(forKey: bundleID)
    }
}
