import Foundation

actor ExecutionService {

    // MARK: - Execute

    func execute(_ workflow: Workflow) async -> ExecutionLog {
        let start = Date()
        var log = ExecutionLog(
            workflowId:   workflow.id,
            workflowName: workflow.name,
            startTime:    start,
            status:       .running,
            triggerType:  .manual
        )

        let result = await run(workflow)
        log.endTime  = Date()
        log.stdout   = result.stdout
        log.stderr   = result.stderr
        log.exitCode = result.exitCode
        log.status   = result.exitCode == 0 ? .success : .failed
        return log
    }

    // MARK: - Internal runner

    private struct RunResult {
        let stdout: String
        let stderr: String
        let exitCode: Int
    }

    private func run(_ workflow: Workflow) async -> RunResult {
        let args = buildArgs(workflow)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", args]

        // Environment
        var env = ProcessInfo.processInfo.environment
        for (k, v) in workflow.environmentVariables { env[k] = v }
        process.environment = env

        // Working directory
        if let wd = workflow.workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath:
                (wd as NSString).expandingTildeInPath)
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError  = errPipe

        do {
            try process.run()
        } catch {
            return RunResult(stdout: "", stderr: error.localizedDescription, exitCode: 1)
        }

        // Timeout
        if let timeout = workflow.timeout {
            let deadline = DispatchTime.now() + timeout
            DispatchQueue.global().asyncAfter(deadline: deadline) {
                if process.isRunning { process.terminate() }
            }
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
                let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                                 encoding: .utf8) ?? ""
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                                 encoding: .utf8) ?? ""
                continuation.resume(returning: RunResult(
                    stdout:   out.trimmingCharacters(in: .whitespacesAndNewlines),
                    stderr:   err.trimmingCharacters(in: .whitespacesAndNewlines),
                    exitCode: Int(process.terminationStatus)
                ))
            }
        }
    }

    // MARK: - Command Builder

    private func buildArgs(_ workflow: Workflow) -> String {
        let cmd = (workflow.command as NSString).expandingTildeInPath
        switch workflow.type {
        case .shortcut:
            return "shortcuts run \"\(cmd)\""
        case .n8n:
            return "n8n execute --id \"\(cmd)\""
        case .shell:
            if cmd.hasSuffix(".sh") || cmd.hasSuffix(".zsh") {
                return "/bin/bash \"\(cmd)\""
            }
            return cmd
        case .node:
            return "node \"\(cmd)\""
        case .python:
            return "python3 \"\(cmd)\""
        }
    }
}
