import UserNotifications
import Foundation

final class NotificationService {

    enum Event {
        case success(_ workflow: Workflow)
        case failure(_ workflow: Workflow, _ stderr: String)
        case skipped(_ workflow: Workflow)
        case schedulerPaused
        case schedulerResumed
    }

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Send

    func send(_ event: Event) {
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch event {
        case .success(let w):
            content.title    = "✅ \(w.name)"
            content.body     = "Workflow completed successfully."
            content.subtitle = w.type.displayName

        case .failure(let w, let err):
            content.title    = "❌ \(w.name)"
            content.body     = err.isEmpty ? "Workflow failed." : String(err.prefix(200))
            content.subtitle = w.type.displayName

        case .skipped(let w):
            content.title = "⏭ \(w.name) skipped"
            content.body  = "The workflow was skipped."

        case .schedulerPaused:
            content.title = "FlowBar Paused"
            content.body  = "All scheduled workflows have been paused."

        case .schedulerResumed:
            content.title = "FlowBar Resumed"
            content.body  = "Scheduled workflows are active again."
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
