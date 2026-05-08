import SwiftUI

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published State

    @Published var workflows: [Workflow] = []
    @Published var isPaused: Bool = false
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published var selectedWorkflowId: UUID? = nil
    @Published var showAddWorkflow: Bool = false
    @Published var showLogs: Bool = false
    @Published var showSettings: Bool = false

    // MARK: - Services

    let repository: WorkflowRepository
    let executor: ExecutionService
    let scheduler: SchedulerService
    let launchAgent: LaunchAgentManager
    let notifications: NotificationService
    let logService: LogService
    let keychain: KeychainService

    // MARK: - Init

    init() {
        self.repository    = WorkflowRepository()
        self.executor      = ExecutionService()
        self.logService    = LogService()
        self.notifications = NotificationService()
        self.keychain      = KeychainService()
        self.launchAgent   = LaunchAgentManager()
        self.scheduler     = SchedulerService()

        self.scheduler.appState = self

        loadWorkflows()
        requestNotificationPermission()
    }

    // MARK: - Derived

    var filteredWorkflows: [Workflow] {
        guard !searchText.isEmpty else { return workflows }
        return workflows.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var runningCount: Int { workflows.filter { $0.lastStatus == .running }.count }
    var failedCount:  Int { workflows.filter { $0.lastStatus == .failed  }.count }

    // MARK: - Load / Save

    func loadWorkflows() {
        workflows = repository.loadWorkflows()
        if workflows.isEmpty {
            workflows = Workflow.examples
            saveWorkflows()
        }
        rescheduleAll()
    }

    func saveWorkflows() {
        repository.saveWorkflows(workflows)
    }

    // MARK: - CRUD

    func addWorkflow(_ workflow: Workflow) {
        workflows.append(workflow)
        saveWorkflows()
        if workflow.enabled && workflow.schedule.type != .manual {
            scheduler.schedule(workflow)
            launchAgent.install(workflow)
        }
    }

    func updateWorkflow(_ workflow: Workflow) {
        guard let idx = workflows.firstIndex(where: { $0.id == workflow.id }) else { return }
        workflows[idx] = workflow
        saveWorkflows()
        launchAgent.uninstall(workflow)
        if workflow.enabled && workflow.schedule.type != .manual {
            launchAgent.install(workflow)
        }
        scheduler.reschedule(workflow)
    }

    func deleteWorkflow(_ workflow: Workflow) {
        scheduler.cancel(workflow)
        launchAgent.uninstall(workflow)
        workflows.removeAll { $0.id == workflow.id }
        saveWorkflows()
    }

    func toggleEnabled(_ workflow: Workflow) {
        var w = workflow
        w.enabled.toggle()
        updateWorkflow(w)
    }

    // MARK: - Execution

    func runWorkflow(_ workflow: Workflow) {
        guard !isPaused else { return }
        let idx = workflows.firstIndex(where: { $0.id == workflow.id })

        Task {
            if let i = idx {
                workflows[i].lastStatus = .running
            }

            let log = await executor.execute(workflow)

            if let i = workflows.firstIndex(where: { $0.id == workflow.id }) {
                workflows[i].lastRun    = log.startTime
                workflows[i].lastStatus = log.status
            }

            logService.append(log)
            saveWorkflows()

            switch log.status {
            case .success: notifications.send(.success(workflow))
            case .failed:  notifications.send(.failure(workflow, log.stderr))
            default: break
            }
        }
    }

    func pauseAll() {
        isPaused = true
        scheduler.pauseAll()
        notifications.send(.schedulerPaused)
    }

    func resumeAll() {
        isPaused = false
        scheduler.resumeAll()
        notifications.send(.schedulerResumed)
    }

    func runAll() {
        workflows.filter(\.enabled).forEach { runWorkflow($0) }
    }

    // MARK: - Scheduling

    private func rescheduleAll() {
        for workflow in workflows where workflow.enabled {
            scheduler.schedule(workflow)
        }
    }

    // MARK: - Helpers

    private func requestNotificationPermission() {
        notifications.requestPermission()
    }

    var selectedWorkflow: Binding<Workflow?> {
        Binding(
            get: { [weak self] in
                guard let self, let id = self.selectedWorkflowId else { return nil }
                return self.workflows.first { $0.id == id }
            },
            set: { [weak self] newVal in
                guard let self else { return }
                if let updated = newVal {
                    self.updateWorkflow(updated)
                } else {
                    self.selectedWorkflowId = nil
                }
            }
        )
    }
}
