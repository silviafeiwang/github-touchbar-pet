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
        if let topRepoToday { return "Today’s main quest: \(shortName(topRepoToday)) ✨" }
        if let topRepoWeek { return "This week’s main quest: \(shortName(topRepoWeek))" }
        return "Boo is waiting for the next public GitHub adventure."
    }

    var report: String {
        latestDescription ?? compactText
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
        struct Commit: Decodable, Sendable { let message: String }
        struct PullRequest: Decodable, Sendable {
            let title: String?
            let merged: Bool?
        }
        struct Issue: Decodable, Sendable { let title: String? }
        struct Release: Decodable, Sendable {
            let name: String?
            let tagName: String?

            enum CodingKeys: String, CodingKey {
                case name
                case tagName = "tag_name"
            }
        }

        let size: Int?
        let action: String?
        let refType: String?
        let ref: String?
        let commits: [Commit]?
        let pullRequest: PullRequest?
        let issue: Issue?
        let release: Release?

        enum CodingKeys: String, CodingKey {
            case size, action, ref, commits, issue, release
            case refType = "ref_type"
            case pullRequest = "pull_request"
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
        case "PushEvent": pushDescription(repoName: repoName)
        case "PullRequestEvent": pullRequestDescription(repoName: repoName)
        case "IssuesEvent": issueDescription(repoName: repoName)
        case "IssueCommentEvent": "The conversation in \(repoName) is moving forward."
        case "CreateEvent": createDescription(repoName: repoName)
        case "ReleaseEvent": releaseDescription(repoName: repoName)
        case "WatchEvent": "You found something worth keeping: \(repoName) ⭐"
        case "ForkEvent": "A new experiment begins with \(repoName)."
        default: "Something is brewing in \(repoName)."
        }
    }

    private func pushDescription(repoName: String) -> String {
        guard let subject = payload.commits?.last?.message
            .split(whereSeparator: \.isNewline).first.map(String.init), !subject.isEmpty else {
            return "You moved \(repoName) forward. Boo approves."
        }
        let clipped = subject.count > 92 ? String(subject.prefix(89)) + "…" : subject
        let extra = max(score - 1, 0)
        if extra > 0 {
            return "Latest in \(repoName): “\(clipped)” + \(extra) more."
        }
        return "Latest in \(repoName): “\(clipped)”"
    }

    private func pullRequestDescription(repoName: String) -> String {
        let title = payload.pullRequest?.title.flatMap(nonempty)
        if payload.pullRequest?.merged == true {
            return title.map { "Shipped in \(repoName): “\($0)” 🎉" }
                ?? "Something just shipped in \(repoName) 🎉"
        }
        if payload.action == "closed" {
            return title.map { "Closed the loop in \(repoName): “\($0)”" }
                ?? "Closed the loop on something in \(repoName)."
        }
        return title.map { "Taking shape in \(repoName): “\($0)”" }
            ?? "A new idea is taking shape in \(repoName)."
    }

    private func issueDescription(repoName: String) -> String {
        let title = payload.issue?.title.flatMap(nonempty)
        if payload.action == "closed" {
            return title.map { "One less loose end in \(repoName): “\($0)”" }
                ?? "One less loose end in \(repoName)."
        }
        return title.map { "Worth a look in \(repoName): “\($0)”" }
            ?? "A new question appeared in \(repoName)."
    }

    private func createDescription(repoName: String) -> String {
        let kind = payload.refType ?? "project"
        if kind == "repository" { return "Welcome to the world, \(repoName)! ✨" }
        let name = payload.ref?.split(separator: "/").last.map(String.init)
        return name.map { "New \(kind) in \(repoName): \($0)" }
            ?? "A fresh \(kind) appeared in \(repoName)."
    }

    private func releaseDescription(repoName: String) -> String {
        let releaseName = payload.release?.name.flatMap(nonempty)
            ?? payload.release?.tagName.flatMap(nonempty)
        return releaseName.map { "\(repoName) shipped \($0) 🚀" }
            ?? "\(repoName) has a fresh release 🚀"
    }

    private func nonempty(_ value: String) -> String? {
        value.isEmpty ? nil : value
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
