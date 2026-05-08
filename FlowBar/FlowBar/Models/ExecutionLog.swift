import Foundation

struct ExecutionLog: Codable, Identifiable {
    var id: UUID = UUID()
    var workflowId: UUID
    var workflowName: String
    var startTime: Date
    var endTime: Date?
    var status: WorkflowStatus
    var stdout: String = ""
    var stderr: String = ""
    var exitCode: Int?
    var triggerType: TriggerType = .manual

    enum TriggerType: String, Codable {
        case manual
        case scheduled
        case dependency
        case webhook
    }

    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    var durationFormatted: String {
        guard let d = duration else { return "–" }
        if d < 1    { return "\(Int(d * 1000))ms" }
        if d < 60   { return String(format: "%.1fs", d) }
        let m = Int(d / 60); let s = Int(d) % 60
        return "\(m)m \(s)s"
    }

    var combinedOutput: String {
        [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

// MARK: - Log Storage

struct LogStore: Codable {
    var logs: [ExecutionLog] = []
    private static let maxLogs = 500

    mutating func append(_ log: ExecutionLog) {
        logs.append(log)
        if logs.count > Self.maxLogs {
            logs.removeFirst(logs.count - Self.maxLogs)
        }
    }

    func logs(for workflowId: UUID) -> [ExecutionLog] {
        logs.filter { $0.workflowId == workflowId }
            .sorted { $0.startTime > $1.startTime }
    }
}
