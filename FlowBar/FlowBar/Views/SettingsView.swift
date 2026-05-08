import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("notifyOnSuccess")      private var notifyOnSuccess      = false
    @AppStorage("notifyOnFailure")      private var notifyOnFailure      = true

    @State private var launchAtLogin = false
    @State private var showLaunchError = false

    var body: some View {
        NavigationStack {
            Form {
                launchAtLoginSection
                notificationsSection
                storageSection
                aboutSection
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 500)
        .onAppear { launchAtLogin = isLaunchAtLoginEnabled() }
        .alert("Could not update login item", isPresented: $showLaunchError) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var launchAtLoginSection: some View {
        Section("Startup") {
            Toggle("Launch FlowBar at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }

            Button("Install example scripts") {
                installExampleScripts()
            }
            .help("Creates ~/.flowbar/scripts/ with starter templates.")
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Enable notifications", isOn: $notificationsEnabled)
            Toggle("Notify on success", isOn: $notifyOnSuccess)
                .disabled(!notificationsEnabled)
            Toggle("Notify on failure", isOn: $notifyOnFailure)
                .disabled(!notificationsEnabled)
        }
    }

    private var storageSection: some View {
        Section {
            LabeledContent("Storage location") {
                Text(appState.repository.storageURL.deletingLastPathComponent().path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Button("Open in Finder") {
                NSWorkspace.shared.open(
                    appState.repository.storageURL.deletingLastPathComponent()
                )
            }

            LabeledContent("Total log entries") {
                Text("\(appState.logService.allLogs.count)")
                    .foregroundStyle(.secondary)
            }

            Button("Clear all logs", role: .destructive) {
                appState.logService.clearAll()
            }
        } header: {
            Text("Data & Storage")
        } footer: {
            Text("Workflows and logs are stored locally. No data leaves your Mac.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: appBuild)
            LabeledContent("macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
        }
    }

    // MARK: - Launch at Login (SMAppService — macOS 13+)

    private func isLaunchAtLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = !enable  // revert toggle
            showLaunchError = true
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func installExampleScripts() {
        let scriptsDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".flowbar/scripts")

        try? FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)

        // Copy bundled scripts
        if let src = Bundle.main.url(forResource: "ai_token_monitor", withExtension: "py") {
            let dst = scriptsDir.appendingPathComponent("ai_token_monitor.py")
            try? FileManager.default.copyItem(at: src, to: dst)
        }

        let gitBackup = """
        #!/bin/bash
        # FlowBar - Git Backup Script
        set -e
        REPOS=("$HOME/Documents")
        for repo in "${REPOS[@]}"; do
            if [ -d "$repo/.git" ]; then
                cd "$repo"
                git add -A
                git diff --cached --quiet || git commit -m "FlowBar auto-backup $(date +%Y-%m-%d)"
                git push origin HEAD 2>/dev/null || true
            fi
        done
        echo "Done."
        """
        try? gitBackup.write(
            to: scriptsDir.appendingPathComponent("git_backup.sh"),
            atomically: true, encoding: .utf8
        )

        // chmod +x
        let chmod = Process()
        chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmod.arguments = ["+x"] + [
            scriptsDir.appendingPathComponent("ai_token_monitor.py").path,
            scriptsDir.appendingPathComponent("git_backup.sh").path
        ]
        try? chmod.run()

        NSWorkspace.shared.open(scriptsDir)
    }
}
