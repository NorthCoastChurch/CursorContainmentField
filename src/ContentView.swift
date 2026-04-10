import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Text(appState.isActive ? "Containment: On" : "Containment: Off")
            .foregroundColor(.secondary)

        Divider()

        Button(appState.isActive ? "Disable Containment" : "Enable Containment") {
            appState.isActive.toggle()
        }

        Divider()

        Button("Quit CursorContainmentField") {
            NSApplication.shared.terminate(nil)
        }
    }
}
