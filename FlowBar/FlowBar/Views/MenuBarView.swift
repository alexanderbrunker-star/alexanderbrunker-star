import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddWorkflow = false
    @State private var showLogs = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            workflowList
            Divider()
            footer
        }
        .background(GlassBackground())
        .frame(width: 400)
        .sheet(isPresented: $showAddWorkflow) {
            AddEditWorkflowView(workflow: nil)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showLogs) {
            LogsView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "bolt.horizontal.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 16, weight: .semibold))
                Text("FlowBar")
                    .font(.system(size: 15, weight: .semibold))
            }

            Spacer()

            // Status summary
            if appState.runningCount > 0 {
                StatusPill(label: "\(appState.runningCount) running", color: .blue)
            }
            if appState.failedCount > 0 {
                StatusPill(label: "\(appState.failedCount) failed", color: .red)
            }

            // Global controls
            HStack(spacing: 4) {
                Button {
                    appState.isPaused ? appState.resumeAll() : appState.pauseAll()
                } label: {
                    Image(systemName: appState.isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .foregroundStyle(appState.isPaused ? .green : .orange)
                }
                .buttonStyle(.plain)
                .help(appState.isPaused ? "Resume All" : "Pause All")

                Button { showAddWorkflow = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Add Workflow")

                Button { showLogs = true } label: {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("View Logs")

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .font(.system(size: 16))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(.system(size: 12))
            TextField("Search workflows…", text: $appState.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !appState.searchText.isEmpty {
                Button { appState.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Workflow List

    private var workflowList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if appState.filteredWorkflows.isEmpty {
                    emptyState
                } else {
                    ForEach(appState.filteredWorkflows) { workflow in
                        WorkflowRowView(workflow: workflow)
                            .environmentObject(appState)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(maxHeight: 420)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(appState.searchText.isEmpty ? "No workflows yet" : "No results")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            if appState.searchText.isEmpty {
                Button("Add your first workflow") { showAddWorkflow = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("\(appState.workflows.filter(\.enabled).count) active · \(appState.workflows.count) total")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            if appState.isPaused {
                HStack(spacing: 4) {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                    Text("Paused").font(.system(size: 11)).foregroundStyle(.orange)
                }
            }

            Button("Quit FlowBar") {
                NSApp.terminate(nil)
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Glass Background

struct GlassBackground: View {
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            VisualEffectView(material: .menu, blendingMode: .behindWindow)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material    = material
        view.blendingMode = blendingMode
        view.state       = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material     = material
        nsView.blendingMode = blendingMode
    }
}
