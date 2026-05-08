import Foundation

/// Manages LaunchAgent plist files in ~/Library/LaunchAgents/
final class LaunchAgentManager {

    private let launchAgentsDir: URL = {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }()

    private let appBundlePath: String = {
        Bundle.main.bundlePath
    }()

    // MARK: - Public

    func install(_ workflow: Workflow) {
        guard workflow.schedule.type != .manual else { return }
        let plist = PlistGenerator.generate(workflow, appBundlePath: appBundlePath)
        let url = plistURL(for: workflow)
        try? plist.write(to: url, atomically: true, encoding: .utf8)
        load(plistURL: url)
    }

    func uninstall(_ workflow: Workflow) {
        let url = plistURL(for: workflow)
        unload(plistURL: url)
        try? FileManager.default.removeItem(at: url)
    }

    func reload(_ workflow: Workflow) {
        uninstall(workflow)
        install(workflow)
    }

    func isInstalled(_ workflow: Workflow) -> Bool {
        FileManager.default.fileExists(atPath: plistURL(for: workflow).path)
    }

    // MARK: - Private

    private func plistURL(for workflow: Workflow) -> URL {
        let label = launchdLabel(for: workflow)
        return launchAgentsDir.appendingPathComponent("\(label).plist")
    }

    private func launchdLabel(for workflow: Workflow) -> String {
        "com.flowbar.\(workflow.id.uuidString.lowercased())"
    }

    private func load(plistURL: URL) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["load", plistURL.path]
        try? proc.run()
    }

    private func unload(plistURL: URL) {
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["unload", plistURL.path]
        try? proc.run()
    }
}
