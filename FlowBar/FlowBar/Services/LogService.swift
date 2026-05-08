import Foundation

final class LogService: ObservableObject {

    @Published private(set) var store = LogStore()
    private let fileURL: URL

    init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FlowBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        self.fileURL = support.appendingPathComponent("logs.json")
        load()
    }

    // MARK: - Public

    func append(_ log: ExecutionLog) {
        store.append(log)
        save()
    }

    func logs(for workflowId: UUID) -> [ExecutionLog] {
        store.logs(for: workflowId)
    }

    var allLogs: [ExecutionLog] {
        store.logs.sorted { $0.startTime > $1.startTime }
    }

    func clearAll() {
        store.logs.removeAll()
        save()
    }

    func clear(for workflowId: UUID) {
        store.logs.removeAll { $0.workflowId == workflowId }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        store = (try? dec.decode(LogStore.self, from: data)) ?? LogStore()
    }

    private func save() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted]
        guard let data = try? enc.encode(store) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
