import Foundation

/// Generates launchd LaunchAgent plist XML for a given Workflow.
enum PlistGenerator {

    static func generate(_ workflow: Workflow, appBundlePath: String) -> String {
        let label   = "com.flowbar.\(workflow.id.uuidString.lowercased())"
        let command = buildCommand(workflow)
        let scheduleKeys = scheduleXML(workflow.schedule)

        let envBlock: String = {
            guard !workflow.environmentVariables.isEmpty else { return "" }
            var lines = "\t<key>EnvironmentVariables</key>\n\t<dict>\n"
            for (k, v) in workflow.environmentVariables.sorted(by: { $0.key < $1.key }) {
                lines += "\t\t<key>\(k)</key>\n\t\t<string>\(v)</string>\n"
            }
            lines += "\t</dict>\n"
            return lines
        }()

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
            "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \t<key>Label</key>
        \t<string>\(label)</string>
        \t<key>ProgramArguments</key>
        \t<array>
        \t\t<string>/bin/bash</string>
        \t\t<string>-c</string>
        \t\t<string>\(command)</string>
        \t</array>
        \(scheduleKeys)\(envBlock)\t<key>RunAtLoad</key>
        \t<false/>
        \t<key>StandardOutPath</key>
        \t<string>\(logPath(workflow, type: "stdout"))</string>
        \t<key>StandardErrorPath</key>
        \t<string>\(logPath(workflow, type: "stderr"))</string>
        </dict>
        </plist>
        """
    }

    // MARK: - Helpers

    private static func buildCommand(_ workflow: Workflow) -> String {
        let cmd = (workflow.command as NSString).expandingTildeInPath
        switch workflow.type {
        case .shortcut: return "shortcuts run &quot;\(cmd)&quot;"
        case .n8n:      return "n8n execute --id &quot;\(cmd)&quot;"
        case .shell:    return "/bin/bash &quot;\(cmd)&quot;"
        case .node:     return "node &quot;\(cmd)&quot;"
        case .python:   return "python3 &quot;\(cmd)&quot;"
        }
    }

    private static func scheduleXML(_ schedule: WorkflowSchedule) -> String {
        switch schedule.type {
        case .manual:
            return ""
        case .interval, .custom:
            let seconds = schedule.intervalMinutes * 60
            return "\t<key>StartInterval</key>\n\t<integer>\(seconds)</integer>\n"
        case .daily:
            return """
            \t<key>StartCalendarInterval</key>
            \t<dict>
            \t\t<key>Hour</key>
            \t\t<integer>\(schedule.hour)</integer>
            \t\t<key>Minute</key>
            \t\t<integer>\(schedule.minute)</integer>
            \t</dict>\n
            """
        case .weekly:
            return """
            \t<key>StartCalendarInterval</key>
            \t<dict>
            \t\t<key>Weekday</key>
            \t\t<integer>\(schedule.weekday)</integer>
            \t\t<key>Hour</key>
            \t\t<integer>\(schedule.hour)</integer>
            \t\t<key>Minute</key>
            \t\t<integer>\(schedule.minute)</integer>
            \t</dict>\n
            """
        }
    }

    private static func logPath(_ workflow: Workflow, type: String) -> String {
        let logDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/FlowBar")
            .path
        let name = workflow.id.uuidString.lowercased()
        return "\(logDir)/\(name).\(type).log"
    }
}
