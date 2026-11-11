import Foundation

struct GitHubInboxSummary: Equatable, Sendable {
    var latestID: String?
    var latestDescription: String?
    var unreadCount: Int

    static let empty = GitHubInboxSummary(latestID: nil, latestDescription: nil, unreadCount: 0)
}

struct GitHubInboxProvider: Sendable {
    private struct Thread: Decodable {
        struct Repository: Decodable { let name: String }
        struct Subject: Decodable {
            let title: String
            let type: String
        }

        let id: String
        let repository: Repository
        let subject: Subject
        let reason: String
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch() async throws -> GitHubInboxSummary {
        guard let token = GitHubCredentialStore.loadToken() else { return .empty }
        var components = URLComponents(string: "https://api.github.com/notifications")!
        components.queryItems = [
            URLQueryItem(name: "all", value: "false"),
            URLQueryItem(name: "per_page", value: "50")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("CommitPetTouchBar/0.4", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.userAuthenticationRequired)
        }
        let threads = try JSONDecoder().decode([Thread].self, from: data)
        let latest = threads.first
        return GitHubInboxSummary(
            latestID: latest?.id,
            latestDescription: latest.map(message),
            unreadCount: threads.count
        )
    }

    private func message(for thread: Thread) -> String {
        let title = clipped(thread.subject.title)
        let repo = thread.repository.name
        return switch thread.reason {
        case "mention": "You were mentioned in \(repo): “\(title)”"
        case "team_mention": "Your team was mentioned in \(repo): “\(title)”"
        case "review_requested": "A review is waiting in \(repo): “\(title)”"
        case "assign": "You were assigned in \(repo): “\(title)”"
        case "comment": "New conversation in \(repo): “\(title)”"
        case "ci_activity": "A workflow needs attention in \(repo): “\(title)”"
        case "security_alert": "GitHub has a security alert for \(repo)."
        case "invitation": "You have a repository invitation from \(repo)."
        default: "New \(thread.subject.type.lowercased()) activity in \(repo): “\(title)”"
        }
    }

    private func clipped(_ value: String) -> String {
        value.count > 88 ? String(value.prefix(85)) + "…" : value
    }
}
