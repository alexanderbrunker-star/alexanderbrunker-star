import SwiftUI

@main
struct FlowBarApp: App {

    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .frame(width: 400)
        } label: {
            MenuBarIcon()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - MenuBarIcon

private struct MenuBarIcon: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.pulse, isActive: appState.runningCount > 0)

            if appState.failedCount > 0 {
                Text("\(appState.failedCount)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
            }
        }
    }

    private var iconName: String {
        if appState.isPaused       { return "pause.circle.fill" }
        if appState.runningCount > 0 { return "bolt.horizontal.fill" }
        if appState.failedCount  > 0 { return "exclamationmark.triangle.fill" }
        return "bolt.horizontal"
    }
}
