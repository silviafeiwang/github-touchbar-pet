import AppKit
import Foundation

@MainActor
final class PetModel: ObservableObject {
    @Published private(set) var stats: PetStats
    @Published private(set) var activity: GitHubActivitySummary = .empty
    @Published private(set) var inbox: GitHubInboxSummary = .empty
    @Published private(set) var statusMessage = "Loading GitHub activity…"
    @Published private(set) var isRefreshing = false

    let username: String
    private let provider: any CommitPetStatsProviding
    private let activityProvider: any GitHubActivityProviding
    private let inboxProvider: GitHubInboxProvider
    private let notifier = GitHubActivityNotifier()
    private var timer: Timer?

    init(
        username: String = UserDefaults.standard.string(forKey: "githubUsername") ?? "silviafeiwang",
        provider: any CommitPetStatsProviding = RemoteSVGStatsProvider(),
        activityProvider: any GitHubActivityProviding = PublicGitHubActivityProvider(),
        inboxProvider: GitHubInboxProvider = GitHubInboxProvider()
    ) {
        self.username = username
        self.provider = provider
        self.activityProvider = activityProvider
        self.inboxProvider = inboxProvider
        self.stats = Self.loadCachedStats(username: username) ?? .placeholder(username: username)
    }

    func start() {
        Task {
            await notifier.requestAuthorization()
            await refresh()
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        statusMessage = "Refreshing GitHub activity…"
        defer { isRefreshing = false }

        var messages: [String] = []
        do {
            let previousToday = stats.todayCount
            stats = try await provider.fetch(username: username)
            cache(stats)
            messages.append(stats.todayCount > previousToday
                ? "New contribution detected — Boo is celebrating!"
                : "Pet stats updated")
        } catch {
            messages.append("cached pet stats")
        }

        do {
            let previousActivityID = activity.latestEventID
            activity = try await activityProvider.fetch(username: username)
            messages.append(activity.compactText)
            await notifier.process(activity)
            if previousActivityID != activity.latestEventID {
                let bubbleMessage = activity.latestDescription ?? activity.compactText
                NotificationCenter.default.post(name: .commitPetMessage, object: bubbleMessage)
            }
        } catch {
            messages.append("activity unavailable")
        }

        if GitHubCredentialStore.loadToken() != nil {
            do {
                let previousInboxID = inbox.latestID
                inbox = try await inboxProvider.fetch()
                messages.append(inbox.unreadCount == 0
                    ? "GitHub inbox clear"
                    : "\(inbox.unreadCount) unread GitHub notification\(inbox.unreadCount == 1 ? "" : "s")")
                if let message = inbox.latestDescription,
                   previousInboxID != nil,
                   previousInboxID != inbox.latestID {
                    NotificationCenter.default.post(name: .commitPetMessage, object: message)
                }
            } catch {
                messages.append("GitHub inbox unavailable")
            }
        } else {
            inbox = .empty
        }

        statusMessage = messages.joined(separator: " · ")
        NotificationCenter.default.post(name: .commitPetStatsDidChange, object: stats)
    }

    private static func cacheURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CommitPetTouchBar", isDirectory: true)
            .appendingPathComponent("stats.json")
    }

    private func cache(_ stats: PetStats) {
        guard let url = Self.cacheURL() else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(stats).write(to: url, options: .atomic)
        } catch {
            statusMessage = "Updated, but could not save cache: \(error.localizedDescription)"
        }
    }

    private static func loadCachedStats(username: String) -> PetStats? {
        guard let url = cacheURL(),
              let data = try? Data(contentsOf: url),
              let stats = try? JSONDecoder().decode(PetStats.self, from: data),
              stats.username == username else { return nil }
        return stats
    }
}

extension Notification.Name {
    static let commitPetStatsDidChange = Notification.Name("CommitPetStatsDidChange")
    static let commitPetMessage = Notification.Name("CommitPetMessage")
}
