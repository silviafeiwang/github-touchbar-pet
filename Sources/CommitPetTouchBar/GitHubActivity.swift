import Foundation

struct GitHubActivitySummary: Equatable, Sendable {
    var topRepoToday: String?
    var topRepoWeek: String?
    var latestEventID: String?
    var latestDescription: String?
    var todayScore: Int
    var weekScore: Int
    var refreshedAt: Date

    static let empty = GitHubActivitySummary(
        topRepoToday: nil,
        topRepoWeek: nil,
        latestEventID: nil,
        latestDescription: nil,
        todayScore: 0,
        weekScore: 0,
        refreshedAt: .distantPast
    )

    var compactText: String {
        if let topRepoToday { return "🏆 Today: \(shortName(topRepoToday))" }
        if let topRepoWeek { return "🏆 Week: \(shortName(topRepoWeek))" }
        return "No public activity yet"
    }

    var report: String {
        let today = topRepoToday.map { "Top today: \(shortName($0)) (\(todayScore))" } ?? "Top today: none"
        let week = topRepoWeek.map { "Top this week: \(shortName($0)) (\(weekScore))" } ?? "Top this week: none"
        let latest = latestDescription.map { "Latest: \($0)" } ?? "Latest: no public activity"
        return "\(today)\n\(week)\n\(latest)"
    }

    private func shortName(_ fullName: String) -> String {
        fullName.split(separator: "/").last.map(String.init) ?? fullName
    }
}

protocol GitHubActivityProviding: Sendable {
    func fetch(username: String) async throws -> GitHubActivitySummary
}

private struct GitHubPublicEvent: Decodable, Sendable {
    struct Repository: Decodable, Sendable { let name: String }
    struct Payload: Decodable, Sendable {
        let size: Int?
        let action: String?
        let refType: String?

        enum CodingKeys: String, CodingKey {
            case size, action
            case refType = "ref_type"
        }
    }

    let id: String
    let type: String
    let repo: Repository
    let payload: Payload
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, repo, payload
        case createdAt = "created_at"
    }

    var score: Int {
        type == "PushEvent" ? max(payload.size ?? 1, 1) : 1
    }

    var description: String {
        let repoName = repo.name.split(separator: "/").last.map(String.init) ?? repo.name
        return switch type {
        case "PushEvent": "Pushed \(score) commit\(score == 1 ? "" : "s") to \(repoName)"
        case "PullRequestEvent": "\(payload.action?.capitalized ?? "Updated") a pull request in \(repoName)"
        case "IssuesEvent": "\(payload.action?.capitalized ?? "Updated") an issue in \(repoName)"
        case "IssueCommentEvent": "Commented in \(repoName)"
        case "CreateEvent": "Created \(payload.refType ?? "something") in \(repoName)"
        case "ReleaseEvent": "Published a release in \(repoName)"
        case "WatchEvent": "Starred \(repoName)"
        case "ForkEvent": "Forked \(repoName)"
        default: "Activity in \(repoName)"
        }
    }
}

struct PublicGitHubActivityProvider: GitHubActivityProviding {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(username: String) async throws -> GitHubActivitySummary {
        guard var components = URLComponents(string: "https://api.github.com/users/\(username)/events/public") else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "per_page", value: "100")]
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("CommitPetTouchBar/0.2", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let events = try decoder.decode([GitHubPublicEvent].self, from: data)
        return summarize(events)
    }

    private func summarize(_ events: [GitHubPublicEvent], now: Date = Date()) -> GitHubActivitySummary {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.date(byAdding: .day, value: -7, to: startOfToday)!

        let todayEvents = events.filter { $0.createdAt >= startOfToday }
        let weekEvents = events.filter { $0.createdAt >= startOfWeek }
        let today = ranking(todayEvents)
        let week = ranking(weekEvents)
        let latest = events.max(by: { $0.createdAt < $1.createdAt })

        return GitHubActivitySummary(
            topRepoToday: today.repo,
            topRepoWeek: week.repo,
            latestEventID: latest?.id,
            latestDescription: latest?.description,
            todayScore: today.score,
            weekScore: week.score,
            refreshedAt: now
        )
    }

    private func ranking(_ events: [GitHubPublicEvent]) -> (repo: String?, score: Int) {
        let totals = Dictionary(grouping: events, by: { $0.repo.name })
            .mapValues { $0.reduce(0) { $0 + $1.score } }
        guard let winner = totals.max(by: { lhs, rhs in
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        }) else { return (nil, 0) }
        return (winner.key, winner.value)
    }
}
