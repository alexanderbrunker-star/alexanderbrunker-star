import Foundation

// MARK: - Enums

enum WorkflowType: String, Codable, CaseIterable, Identifiable {
    case shortcut
    case n8n
    case shell
    case node
    case python

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shortcut: return "Apple Shortcut"
        case .n8n:      return "n8n Workflow"
        case .shell:    return "Shell Script"
        case .node:     return "Node.js Script"
        case .python:   return "Python Script"
        }
    }

    var icon: String {
        switch self {
        case .shortcut: return "square.stack.3d.up.fill"
        case .n8n:      return "arrow.triangle.branch"
        case .shell:    return "terminal.fill"
        case .node:     return "leaf.fill"
        case .python:   return "chevron.left.forwardslash.chevron.right"
        }
    }

    var commandPrefix: String {
        switch self {
        case .shortcut: return "shortcuts run "
        case .n8n:      return "n8n execute --id "
        case .shell:    return "/bin/bash "
        case .node:     return "node "
        case .python:   return "python3 "
        }
    }
}

enum WorkflowStatus: String, Codable {
    case idle
    case running
    case success
    case failed
    case skipped
    case disabled

    var color: String {
        switch self {
        case .idle:     return "gray"
        case .running:  return "blue"
        case .success:  return "green"
        case .failed:   return "red"
        case .skipped:  return "orange"
        case .disabled: return "gray"
        }
    }

    var icon: String {
        switch self {
        case .idle:     return "circle"
        case .running:  return "arrow.clockwise.circle.fill"
        case .success:  return "checkmark.circle.fill"
        case .failed:   return "xmark.circle.fill"
        case .skipped:  return "forward.circle.fill"
        case .disabled: return "pause.circle"
        }
    }
}

// MARK: - Schedule

enum ScheduleType: String, Codable, CaseIterable, Identifiable {
    case manual
    case interval
    case daily
    case weekly
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual:   return "Manual Only"
        case .interval: return "Every N Minutes"
        case .daily:    return "Daily"
        case .weekly:   return "Weekly"
        case .custom:   return "Custom Interval"
        }
    }
}

struct WorkflowSchedule: Codable, Equatable {
    var type: ScheduleType = .manual
    var intervalMinutes: Int = 60       // for .interval / .custom (in minutes)
    var hour: Int = 9                   // for .daily / .weekly
    var minute: Int = 0
    var weekday: Int = 2                // 1=Sunday … 7=Saturday, for .weekly

    var nextRunDescription: String {
        switch type {
        case .manual:
            return "Manual only"
        case .interval:
            return "Every \(intervalMinutes)m"
        case .daily:
            return "Daily \(String(format: "%02d:%02d", hour, minute))"
        case .weekly:
            let days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
            let day  = days[max(0, min(weekday - 1, 6))]
            return "\(day) \(String(format: "%02d:%02d", hour, minute))"
        case .custom:
            return "Every \(intervalMinutes) min"
        }
    }
}

// MARK: - Workflow

struct Workflow: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var description: String = ""
    var type: WorkflowType
    var command: String                 // path, shortcut name, or n8n workflow ID
    var enabled: Bool = true
    var schedule: WorkflowSchedule = WorkflowSchedule()
    var lastRun: Date? = nil
    var lastStatus: WorkflowStatus = .idle
    var tags: [String] = []
    var environmentVariables: [String: String] = [:]
    var timeout: TimeInterval? = nil    // seconds; nil = no timeout
    var retryCount: Int = 0
    var workingDirectory: String? = nil
    var createdAt: Date = Date()

    static func == (lhs: Workflow, rhs: Workflow) -> Bool {
        lhs.id == rhs.id
    }

    // Human-readable command preview
    var commandPreview: String {
        switch type {
        case .shortcut: return "shortcuts run \"\(command)\""
        case .n8n:      return "n8n execute --id \(command)"
        case .shell:    return command
        case .node:     return "node \(command)"
        case .python:   return "python3 \(command)"
        }
    }
}

// MARK: - Example Workflows

extension Workflow {
    static var examples: [Workflow] {
        [
            Workflow(
                name: "AI Token Monitor",
                description: "Monitors Claude & OpenAI token usage. Logs 5h budget alert and creates weekly reset meeting in Apple Calendar named 'AI'.",
                type: .python,
                command: "~/.flowbar/scripts/ai_token_monitor.py",
                enabled: true,
                schedule: WorkflowSchedule(
                    type: .interval,
                    intervalMinutes: 5
                ),
                tags: ["ai", "monitoring", "calendar"],
                environmentVariables: [
                    "OPENAI_ORG": "",
                    "ANTHROPIC_ORG": ""
                ]
            ),
            Workflow(
                name: "Daily Git Backup",
                description: "Commits and pushes any pending changes to remote.",
                type: .shell,
                command: "~/.flowbar/scripts/git_backup.sh",
                enabled: false,
                schedule: WorkflowSchedule(
                    type: .daily,
                    hour: 23,
                    minute: 0
                ),
                tags: ["git", "backup"]
            ),
            Workflow(
                name: "Weekly Report",
                description: "Generates weekly summary and sends via n8n.",
                type: .n8n,
                command: "weekly-report-workflow-id",
                enabled: false,
                schedule: WorkflowSchedule(
                    type: .weekly,
                    hour: 8,
                    minute: 0,
                    weekday: 2
                ),
                tags: ["report", "n8n"]
            )
        ]
    }
}
