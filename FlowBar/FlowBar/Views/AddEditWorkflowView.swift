import SwiftUI

struct AddEditWorkflowView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    // Pass nil for "Add", existing Workflow for "Edit"
    let existing: Workflow?

    @State private var name: String
    @State private var description: String
    @State private var type: WorkflowType
    @State private var command: String
    @State private var enabled: Bool
    @State private var schedule: WorkflowSchedule
    @State private var tagsText: String
    @State private var envVarsText: String
    @State private var timeout: String
    @State private var retryCount: Int
    @State private var workingDirectory: String

    init(workflow: Workflow?) {
        self.existing = workflow
        let w = workflow ?? Workflow(name: "", type: .shell, command: "")
        _name              = State(initialValue: w.name)
        _description       = State(initialValue: w.description)
        _type              = State(initialValue: w.type)
        _command           = State(initialValue: w.command)
        _enabled           = State(initialValue: w.enabled)
        _schedule          = State(initialValue: w.schedule)
        _tagsText          = State(initialValue: w.tags.joined(separator: ", "))
        _envVarsText       = State(initialValue: w.environmentVariables
                                      .map { "\($0.key)=\($0.value)" }
                                      .joined(separator: "\n"))
        _timeout           = State(initialValue: w.timeout.map { String($0) } ?? "")
        _retryCount        = State(initialValue: w.retryCount)
        _workingDirectory  = State(initialValue: w.workingDirectory ?? "")
    }

    var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name *", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)

                    Picker("Type", selection: $type) {
                        ForEach(WorkflowType.allCases) { t in
                            Label(t.displayName, systemImage: t.icon).tag(t)
                        }
                    }

                    Toggle("Enabled", isOn: $enabled)
                    TextField("Tags (comma separated)", text: $tagsText)
                }

                Section {
                    TextField(commandPlaceholder, text: $command, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.system(.body, design: .monospaced))

                    if !command.isEmpty {
                        Label(previewCommand, systemImage: "terminal")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    TextField("Working directory (optional)", text: $workingDirectory)
                } header: {
                    Text(commandSectionTitle)
                } footer: {
                    commandHint
                }

                Section("Schedule") {
                    Picker("Trigger", selection: $schedule.type) {
                        ForEach(ScheduleType.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }

                    switch schedule.type {
                    case .manual:
                        Label("Triggered manually only", systemImage: "hand.tap")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    case .interval, .custom:
                        HStack {
                            Text("Interval")
                            Spacer()
                            TextField("60", value: $schedule.intervalMinutes, format: .number)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                            Text("minutes")
                                .foregroundStyle(.secondary)
                        }
                    case .daily:
                        HStack {
                            Text("Time")
                            Spacer()
                            TextField("9", value: $schedule.hour, format: .number)
                                .frame(width: 40)
                                .multilineTextAlignment(.trailing)
                            Text(":")
                            TextField("00", value: $schedule.minute, format: .number)
                                .frame(width: 40)
                        }
                    case .weekly:
                        Picker("Weekday", selection: $schedule.weekday) {
                            Text("Sunday").tag(1)
                            Text("Monday").tag(2)
                            Text("Tuesday").tag(3)
                            Text("Wednesday").tag(4)
                            Text("Thursday").tag(5)
                            Text("Friday").tag(6)
                            Text("Saturday").tag(7)
                        }
                        HStack {
                            Text("Time")
                            Spacer()
                            TextField("9", value: $schedule.hour, format: .number)
                                .frame(width: 40)
                                .multilineTextAlignment(.trailing)
                            Text(":")
                            TextField("00", value: $schedule.minute, format: .number)
                                .frame(width: 40)
                        }
                    }
                }

                Section("Advanced") {
                    HStack {
                        Text("Timeout")
                        Spacer()
                        TextField("none", text: $timeout)
                            .frame(width: 70)
                            .multilineTextAlignment(.trailing)
                        Text("seconds").foregroundStyle(.secondary)
                    }

                    Stepper("Retry on failure: \(retryCount)×", value: $retryCount, in: 0...5)
                }

                Section {
                    TextEditor(text: $envVarsText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 80)
                } header: {
                    Text("Environment Variables")
                } footer: {
                    Text("One per line, KEY=VALUE format.")
                        .font(.system(size: 11))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Workflow" : "New Workflow")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        save()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || command.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 560)
    }

    // MARK: - Helpers

    private var commandSectionTitle: String {
        switch type {
        case .shortcut: return "Shortcut Name"
        case .n8n:      return "n8n Workflow ID"
        default:        return "Script Path"
        }
    }

    private var commandPlaceholder: String {
        switch type {
        case .shortcut: return "e.g. My Morning Shortcut"
        case .n8n:      return "e.g. abc123-workflow-id"
        case .shell:    return "e.g. ~/.flowbar/scripts/backup.sh"
        case .node:     return "e.g. ~/.flowbar/scripts/index.js"
        case .python:   return "e.g. ~/.flowbar/scripts/monitor.py"
        }
    }

    private var previewCommand: String {
        let cmd = command.isEmpty ? "…" : command
        switch type {
        case .shortcut: return "shortcuts run \"\(cmd)\""
        case .n8n:      return "n8n execute --id \"\(cmd)\""
        case .shell:    return "/bin/bash \"\(cmd)\""
        case .node:     return "node \"\(cmd)\""
        case .python:   return "python3 \"\(cmd)\""
        }
    }

    @ViewBuilder
    private var commandHint: some View {
        switch type {
        case .shortcut:
            Text("Enter the exact name of your Apple Shortcut.")
        case .n8n:
            Text("Find the workflow ID in your n8n instance.")
        default:
            Text("Tilde (~) paths are supported. Make scripts executable with chmod +x.")
        }
    }

    private func save() {
        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var envVars: [String: String] = [:]
        for line in envVarsText.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                envVars[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
                    String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }

        var w = existing ?? Workflow(name: name, type: type, command: command)
        w.name             = name.trimmingCharacters(in: .whitespaces)
        w.description      = description
        w.type             = type
        w.command          = command.trimmingCharacters(in: .whitespaces)
        w.enabled          = enabled
        w.schedule         = schedule
        w.tags             = tags
        w.environmentVariables = envVars
        w.timeout          = Double(timeout)
        w.retryCount       = retryCount
        w.workingDirectory = workingDirectory.isEmpty ? nil : workingDirectory

        if isEditing {
            appState.updateWorkflow(w)
        } else {
            appState.addWorkflow(w)
        }
    }
}
