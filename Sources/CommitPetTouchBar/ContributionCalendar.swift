import Foundation

/// Daily contribution counts keyed by "yyyy-MM-dd", as shown on the GitHub profile graph.
struct ContributionCalendar: Equatable, Sendable {
    var dailyCounts: [String: Int]

    func count(on date: Date, calendar: Calendar = .current) -> Int {
        dailyCounts[Self.dayKey(date, calendar)] ?? 0
    }

    var total: Int { dailyCounts.values.reduce(0, +) }

    /// Consecutive days with contributions, ending today — or yesterday if today
    /// is still empty, since the streak isn't broken until the day is over.
    func streak(endingAt today: Date, calendar: Calendar = .current) -> Int {
        var day = today
        if count(on: day, calendar: calendar) == 0 {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var length = 0
        while count(on: day, calendar: calendar) > 0 {
            length += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return length
    }

    /// Empty days in a row before today.
    func idleDays(before today: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.date(byAdding: .day, value: -1, to: today)!
        var idle = 0
        while count(on: day, calendar: calendar) == 0, idle < 30 {
            idle += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return idle
    }

    static func dayKey(_ date: Date, _ calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    /// Parses the public profile graph at github.com/users/<name>/contributions.
    /// Each day cell has an id and data-date; its count lives in a matching tooltip.
    static func parsePublicGraph(_ html: String) -> ContributionCalendar {
        func matches(_ pattern: String) -> [[String]] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            let range = NSRange(html.startIndex..., in: html)
            return regex.matches(in: html, range: range).map { match in
                (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: html).map { String(html[$0]) } }
            }
        }

        var dateForID: [String: String] = [:]
        for groups in matches(#"data-date="(\d{4}-\d{2}-\d{2})"[^>]*?\sid="([^"]+)""#) where groups.count == 2 {
            dateForID[groups[1]] = groups[0]
        }
        var counts: [String: Int] = [:]
        for groups in matches(#"<tool-tip[^>]*?\sfor="([^"]+)"[^>]*>\s*(No|[\d,]+) contribution"#) where groups.count == 2 {
            guard let date = dateForID[groups[0]] else { continue }
            counts[date] = Int(groups[1].replacingOccurrences(of: ",", with: "")) ?? 0
        }
        return ContributionCalendar(dailyCounts: counts)
    }
}

/// Reads the contribution graph straight from GitHub. Signed in, it uses GraphQL
/// (includes private contributions if the profile shows them); otherwise it reads
/// the public profile graph, so no login or profile workflow is required.
struct ContributionCalendarProvider: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(username: String, now: Date = Date()) async throws -> ContributionCalendar {
        if let token = GitHubCredentialStore.loadToken(),
           let calendar = try? await fetchGraphQL(username: username, token: token, now: now) {
            return calendar
        }
        return try await fetchPublicGraph(username: username)
    }

    private func fetchPublicGraph(username: String) async throws -> ContributionCalendar {
        guard let url = URL(string: "https://github.com/users/\(username)/contributions") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("CommitPetTouchBar/0.6", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let calendar = ContributionCalendar.parsePublicGraph(String(decoding: data, as: UTF8.self))
        guard !calendar.dailyCounts.isEmpty else { throw URLError(.cannotParseResponse) }
        return calendar
    }

    private func fetchGraphQL(username: String, token: String, now: Date) async throws -> ContributionCalendar {
        let calendar = Calendar.current
        // GitHub allows at most one year per contributionsCollection query.
        let start = calendar.date(byAdding: .day, value: -364, to: calendar.startOfDay(for: now))!
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withInternetDateTime]

        let body: [String: Any] = [
            "query": """
            query($login: String!, $from: DateTime!, $to: DateTime!) {
              user(login: $login) {
                contributionsCollection(from: $from, to: $to) {
                  contributionCalendar { weeks { contributionDays { date contributionCount } } }
                }
              }
            }
            """,
            "variables": [
                "login": username,
                "from": formatter.string(from: start),
                "to": formatter.string(from: now),
            ],
        ]

        var request = URLRequest(url: URL(string: "https://api.github.com/graphql")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("CommitPetTouchBar/0.6", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        struct Day: Decodable { let date: String; let contributionCount: Int }
        struct Week: Decodable { let contributionDays: [Day] }
        struct CalendarField: Decodable { let weeks: [Week] }
        struct Collection: Decodable { let contributionCalendar: CalendarField }
        struct User: Decodable { let contributionsCollection: Collection }
        struct DataField: Decodable { let user: User? }
        struct Envelope: Decodable { let data: DataField? }

        guard let weeks = try JSONDecoder().decode(Envelope.self, from: data)
            .data?.user?.contributionsCollection.contributionCalendar.weeks else {
            throw URLError(.cannotParseResponse)
        }
        var counts: [String: Int] = [:]
        for day in weeks.flatMap(\.contributionDays) { counts[day.date] = day.contributionCount }
        return ContributionCalendar(dailyCounts: counts)
    }
}

extension PetStats {
    /// Boo's own rules, computed from the contribution graph.
    static func from(
        _ calendar: ContributionCalendar,
        name: String,
        username: String,
        now: Date = Date()
    ) -> PetStats {
        let today = calendar.count(on: now)
        let hour = Calendar.current.component(.hour, from: now)
        let idle = calendar.idleDays(before: now)

        let mood: PetMood
        if today > 0 {
            mood = .happy
        } else if idle >= 3 {
            mood = .sick
        } else if idle == 0 && hour < StreakReminderSchedule.slots[0].hour {
            mood = .content
        } else {
            mood = .hungry
        }

        return PetStats(
            name: name,
            username: username,
            level: level(forYearlyTotal: calendar.total),
            mood: mood,
            streak: calendar.streak(endingAt: now),
            todayCount: today,
            total: calendar.total,
            refreshedAt: now
        )
    }

    /// Grows quickly at first, then slows: 20 contributions → Lv2, 80 → Lv3, 500 → Lv6.
    static func level(forYearlyTotal total: Int) -> Int {
        1 + Int((Double(max(total, 0)) / 20).squareRoot())
    }
}
