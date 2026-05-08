import SwiftUI

struct WorkflowDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let workflow: Workflow
    @State private var edited: Workflow

    init(workflow: Workflow) {
        self.workflow = workflow
        self._edited = State(initialValue: workflow)
    }

    var body: some View {
        NavigationStack {
            Form {
                generalSection
                commandSection
                scheduleSection
                advancedSection
                logsSection
            }
            .formStyle(.grouped)
            .navigationTitle(workflow.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.updateWorkflow(edited)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        appState.runWorkflow(edited)
                        dismiss()
                    } label: {
                        Label("Run Now", systemImage: "play.fill")
                    }
                    .disabled(!edited.enabled || appState.isPaused)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 580)
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section("General") {
            LabeledContent("Name") {
                TextField("Workflow name", text: $edited.name)
            }
            LabeledContent("Description") {
                TextField("Optional description", text: $edited.description, axis: .vertical)
                    .lineLimit(2...4)
            }
            LabeledContent("Type") {
                Picker("", selection: $edited.type) {
                    ForEach(WorkflowType.allCases) { type in
                        Label(type.displayName, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            Toggle("Enabled", isOn: $edited.enabled)
            LabeledContent("Tags") {
                TextField("comma, separated, tags", text: tagsBinding)
            }
        }
    }

    private var commandSection: some View {
        Section("Command / Path") {
            LabeledContent(commandLabel) {
                TextField(commandPlaceholder, text: $edited.command, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.system(.body, design: .monospaced))
            }
            LabeledContent("Preview") {
                Text(edited.commandPreview)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            LabeledContent("Working Dir") {
                TextField("/optional/working/directory", text: wdBinding)
            }
        }
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            LabeledContent("Trigger") {
                Picker("", selection: $edited.schedule.type) {
                    ForEach(ScheduleType.allCases) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            switch edited.schedule.type {
            case .manual:
                EmptyView()
            case .interval, .custom:
                LabeledContent("Every (minutes)") {
                    TextField("", value: $edited.schedule.intervalMinutes, format: .number)
                        .frame(width: 80)
                }
            case .daily:
                HStack {
                    LabeledContent("Time") {
                        HStack {
                            TextField("H", value: $edited.schedule.hour, format: .number)
                                .frame(width: 50)
                            Text(":")
                            TextField("MM", value: $edited.schedule.minute, format: .number)
                                .frame(width: 50)
                        }
                    }
                }
            case .weekly:
                LabeledContent("Weekday") {
                    Picker("", selection: $edited.schedule.weekday) {
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                        Text("Tuesday").tag(3)
                        Text("Wednesday").tag(4)
                        Text("Thursday").tag(5)
                        Text("Friday").tag(6)
                        Text("Saturday").tag(7)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                LabeledContent("Time") {
                    HStack {
                        TextField("H", value: $edited.schedule.hour, format: .number)
                            .frame(width: 50)
                        Text(":")
                        TextField("MM", value: $edited.schedule.minute, format: .number)
                            .frame(width: 50)
                    }
                }
            }

            LabeledContent("Next run") {
                Text(edited.schedule.nextRunDescription)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var advancedSection: some View {
        Section("Advanced") {
            LabeledContent("Timeout (s)") {
                TextField("none", value: $edited.timeout, format: .number)
                    .frame(width: 80)
            }
            LabeledContent("Retry count") {
                Stepper("\(edited.retryCount)", value: $edited.retryCount, in: 0...5)
            }
        }
    }

    private var logsSection: some View {
        Section("Recent Logs") {
            let recentLogs = appState.logService.logs(for: workflow.id).prefix(3)
            if recentLogs.isEmpty {
                Text("No logs yet").foregroundStyle(.secondary).font(.system(size: 12))
            } else {
                ForEach(Array(recentLogs)) { log in
                    LogRowCompact(log: log)
                }
            }
        }
    }

    // MARK: - Helpers

    private var commandLabel: String {
        switch edited.type {
        case .shortcut: return "Shortcut Name"
        case .n8n:      return "Workflow ID"
        default:        return "Script Path"
        }
    }

    private var commandPlaceholder: String {
        switch edited.type {
        case .shortcut: return "My Shortcut Name"
        case .n8n:      return "abc123-workflow-id"
        case .shell:    return "~/.flowbar/scripts/my_script.sh"
        case .node:     return "~/.flowbar/scripts/my_script.js"
        case .python:   return "~/.flowbar/scripts/my_script.py"
        }
    }

    private var tagsBinding: Binding<String> {
        Binding(
            get: { edited.tags.joined(separator: ", ") },
            set: { edited.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        )
    }

    private var wdBinding: Binding<String> {
        Binding(
            get: { edited.workingDirectory ?? "" },
            set: { edited.workingDirectory = $0.isEmpty ? nil : $0 }
        )
    }
}

// MARK: - Compact Log Row

struct LogRowCompact: View {
    let log: ExecutionLog

    var body: some View {
        HStack {
            Image(systemName: log.status.icon)
                .foregroundStyle(statusColor)
                .font(.system(size: 12))
            Text(log.startTime, style: .relative)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(log.durationFormatted)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
            if log.status == .failed {
                Text("exit \(log.exitCode ?? -1)")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }
    }

    private var statusColor: Color {
        switch log.status {
        case .success:  return .green
        case .failed:   return .red
        case .skipped:  return .orange
        case .running:  return .blue
        default:        return .gray
        }
    }
}
