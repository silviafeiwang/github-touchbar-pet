import Foundation
import UserNotifications

@MainActor
final class GitHubActivityNotifier {
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func process(_ summary: GitHubActivitySummary) async {
        let previousEventID = defaults.string(forKey: "lastNotifiedGitHubEventID")
        if let latestID = summary.latestEventID {
            defaults.set(latestID, forKey: "lastNotifiedGitHubEventID")
            if let previousEventID, previousEventID != latestID, let description = summary.latestDescription {
                await deliver(title: "👻 New GitHub activity", body: description)
            }
        }

        let dayKey = Self.dayFormatter.string(from: Date())
        if defaults.string(forKey: "lastBooDailyReport") != dayKey {
            defaults.set(dayKey, forKey: "lastBooDailyReport")
            await deliver(
                title: "👻 Boo’s GitHub report",
                body: summary.report.replacingOccurrences(of: "\n", with: " · ")
            )
        }
    }

    private func deliver(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
