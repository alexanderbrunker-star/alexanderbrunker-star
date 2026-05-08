import Foundation

final class WorkflowRepository {

    private let fileURL: URL

    init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FlowBar", isDirectory: true)

        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        self.fileURL = support.appendingPathComponent("workflows.json")
    }

    func loadWorkflows() -> [Workflow] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Workflow].self, from: data)) ?? []
    }

    func saveWorkflows(_ workflows: [Workflow]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(workflows) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    var storageURL: URL { fileURL }
}
