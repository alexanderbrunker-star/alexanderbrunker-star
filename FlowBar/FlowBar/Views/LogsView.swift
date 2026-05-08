import SwiftUI

struct LogsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var searchText    = ""
    @State private var filterStatus: WorkflowStatus? = nil
    @State private var selectedLog: ExecutionLog? = nil

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let log = selectedLog {
                LogDetailView(log: log)
            } else {
                ContentUnavailableView("Select a log", systemImage: "doc.text", description: Text("Choose a run from the list."))
            }
        }
        .navigationTitle("Run Logs")
        .frame(minWidth: 720, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Clear All", role: .destructive) {
                    appState.logService.clearAll()
                    selectedLog = nil
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search logs…")
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            logList
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "All",     isActive: filterStatus == nil)    { filterStatus = nil }
                FilterChip(label: "✅ Success", isActive: filterStatus == .success) { filterStatus = .success }
                FilterChip(label: "❌ Failed",  isActive: filterStatus == .failed)  { filterStatus = .failed }
                FilterChip(label: "⏭ Skipped", isActive: filterStatus == .skipped) { filterStatus = .skipped }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private var logList: some View {
        let logs = filteredLogs
        return Group {
            if logs.isEmpty {
                ContentUnavailableView("No logs", systemImage: "doc.text", description: Text("Runs will appear here."))
            } else {
                List(logs, id: \.id, selection: $selectedLog) { log in
                    LogListRow(log: log)
                        .tag(log)
                }
                .listStyle(.plain)
            }
        }
    }

    private var filteredLogs: [ExecutionLog] {
        appState.logService.allLogs.filter { log in
            let matchesSearch = searchText.isEmpty ||
                log.workflowName.localizedCaseInsensitiveContains(searchText) ||
                log.stdout.localizedCaseInsensitiveContains(searchText) ||
                log.stderr.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = filterStatus == nil || log.status == filterStatus
            return matchesSearch && matchesFilter
        }
    }
}

// MARK: - Log List Row

struct LogListRow: View {
    let log: ExecutionLog

    var body: some View {
        HStack(spacing: 10) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(log.workflowName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(log.startTime, style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(log.startTime, style: .time)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(log.durationFormatted)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusIcon: some View {
        Image(systemName: log.status.icon)
            .font(.system(size: 14))
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch log.status {
        case .success: return .green
        case .failed:  return .red
        case .skipped: return .orange
        case .running: return .blue
        default:       return .gray
        }
    }
}

// MARK: - Log Detail View

struct LogDetailView: View {
    let log: ExecutionLog
    @State private var copiedOutput = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.workflowName)
                            .font(.system(size: 18, weight: .semibold))
                        HStack(spacing: 8) {
                            Label(log.startTime.formatted(date: .abbreviated, time: .standard),
                                  systemImage: "calendar")
                            Label(log.durationFormatted, systemImage: "clock")
                            if let code = log.exitCode {
                                Label("exit \(code)", systemImage: "number.circle")
                                    .foregroundStyle(code == 0 ? .green : .red)
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: log.status.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(statusColor)
                }

                Divider()

                // stdout
                if !log.stdout.isEmpty {
                    outputBlock(title: "Standard Output", content: log.stdout, color: .primary)
                }

                // stderr
                if !log.stderr.isEmpty {
                    outputBlock(title: "Standard Error", content: log.stderr, color: .red)
                }

                if log.stdout.isEmpty && log.stderr.isEmpty {
                    Text("No output captured.")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            .padding(20)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log.combinedOutput, forType: .string)
                    copiedOutput = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedOutput = false }
                } label: {
                    Label(copiedOutput ? "Copied!" : "Copy Output",
                          systemImage: copiedOutput ? "checkmark" : "doc.on.doc")
                }
                .disabled(log.combinedOutput.isEmpty)
            }
        }
    }

    private func outputBlock(title: String, content: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(content)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(color)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var statusColor: Color {
        switch log.status {
        case .success: return .green
        case .failed:  return .red
        case .skipped: return .orange
        case .running: return .blue
        default:       return .gray
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isActive ? Color.blue : Color.secondary.opacity(0.15))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
