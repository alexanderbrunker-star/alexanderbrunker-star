import Foundation

@MainActor
final class SchedulerService {

    weak var appState: AppState?
    private var timers: [UUID: Timer] = [:]
    private var isPaused = false

    // MARK: - Public

    func schedule(_ workflow: Workflow) {
        cancel(workflow)
        guard workflow.enabled, !isPaused else { return }

        switch workflow.schedule.type {
        case .manual:
            break
        case .interval, .custom:
            let interval = TimeInterval(workflow.schedule.intervalMinutes * 60)
            guard interval > 0 else { break }
            let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.appState?.runWorkflow(workflow)
                }
            }
            timers[workflow.id] = timer
        case .daily:
            scheduleDailyOrWeekly(workflow)
        case .weekly:
            scheduleDailyOrWeekly(workflow)
        }
    }

    func reschedule(_ workflow: Workflow) {
        cancel(workflow)
        if workflow.enabled { schedule(workflow) }
    }

    func cancel(_ workflow: Workflow) {
        timers[workflow.id]?.invalidate()
        timers.removeValue(forKey: workflow.id)
    }

    func pauseAll() {
        isPaused = true
        for (_, timer) in timers { timer.invalidate() }
        timers.removeAll()
    }

    func resumeAll() {
        isPaused = false
        appState?.workflows.filter(\.enabled).forEach { schedule($0) }
    }

    // MARK: - Private

    private func scheduleDailyOrWeekly(_ workflow: Workflow) {
        let fireDate = nextFireDate(for: workflow.schedule)
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        // Fire once at the correct time, then reschedule
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.appState?.runWorkflow(workflow)
                self.schedule(workflow)  // reschedule for next occurrence
            }
        }
        timers[workflow.id] = timer
    }

    private func nextFireDate(for schedule: WorkflowSchedule) -> Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let now = Date()
        let comps: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second, .weekday]
        var dc = cal.dateComponents(comps, from: now)

        dc.second = 0
        dc.hour   = schedule.hour
        dc.minute = schedule.minute

        if schedule.type == .weekly {
            // Advance to next occurrence of the target weekday
            var candidate = cal.nextDate(after: now,
                                         matching: DateComponents(weekday: schedule.weekday,
                                                                   hour: schedule.hour,
                                                                   minute: schedule.minute),
                                         matchingPolicy: .nextTime) ?? now
            if candidate <= now {
                candidate = cal.date(byAdding: .weekOfYear, value: 1, to: candidate) ?? candidate
            }
            return candidate
        }

        guard var date = cal.date(from: dc) else { return now }
        if date <= now { date = cal.date(byAdding: .day, value: 1, to: date) ?? date }
        return date
    }
}
