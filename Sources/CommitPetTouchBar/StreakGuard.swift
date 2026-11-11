import Foundation

/// Live view of the contribution graph: today's count and the current streak.
struct LiveStreak: Sendable, Equatable {
    var today: Int
    /// nil when only the public events fallback was available.
    var streak: Int?

    /// Consecutive days with contributions, ending today — or yesterday if today
    /// is still empty, since the streak isn't broken until the day is over.
    static func streak(dailyCounts: [String: Int], today: Date, calendar: Calendar = .current) -> Int {
        var day = today
        if (dailyCounts[dayKey(day, calendar)] ?? 0) == 0 {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while (dailyCounts[dayKey(day, calendar)] ?? 0) > 0 {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    static func dayKey(_ date: Date, _ calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
}

/// Reads the contribution graph directly instead of waiting for the once-a-day
/// commit-pet SVG. With a signed-in token this uses GitHub's GraphQL contribution
/// calendar (the same green squares as the profile). Without a token it estimates
/// today from the public events feed, which can lag and misses private work.
struct LiveStreakProvider: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(username: String, fallbackEventsToday: Int, now: Date = Date()) async -> LiveStreak {
        let fallback = LiveStreak(today: fallbackEventsToday, streak: nil)
        guard let token = GitHubCredentialStore.loadToken() else { return fallback }
        do {
            let counts = try await fetchDailyCounts(username: username, token: token, now: now)
            return LiveStreak(
                today: counts[LiveStreak.dayKey(now)] ?? 0,
                streak: LiveStreak.streak(dailyCounts: counts, today: now)
            )
        } catch {
            return fallback
        }
    }

    private func fetchDailyCounts(username: String, token: String, now: Date) async throws -> [String: Int] {
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
        request.setValue("CommitPetTouchBar/0.5", forHTTPHeaderField: "User-Agent")
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
        return counts
    }
}

/// Decides when Boo should nag about an unfed streak. Pure logic so it can be self-tested.
struct StreakReminderSchedule: Sendable {
    struct Slot: Sendable, Equatable {
        let hour: Int
        let id: String
    }

    /// Reminders escalate through the day; each fires at most once per day.
    static let slots: [Slot] = [
        Slot(hour: 10, id: "morning"),
        Slot(hour: 15, id: "afternoon"),
        Slot(hour: 20, id: "evening"),
        Slot(hour: 22, id: "lastCall"),
    ]

    /// The latest slot that has started and hasn't been shown yet today, if any.
    static func dueSlot(hour: Int, alreadyShown: Set<String>) -> Slot? {
        slots.last(where: { $0.hour <= hour }).flatMap { alreadyShown.contains($0.id) ? nil : $0 }
    }

    static func message(for slot: Slot, streak: Int) -> String {
        let streakText = streak > 0 ? "your 🔥\(streak)-day streak" : "a new streak"
        return switch slot.id {
        case "morning": "New day, empty belly 🍙 No commits yet — feed me something small to keep \(streakText)?"
        case "afternoon": "Boo is getting hungry… still no commits today. One tiny commit keeps \(streakText) alive."
        case "evening": "It’s evening and Boo hasn’t eaten 😢 Push a commit to protect \(streakText)!"
        default: "Last call! 🔥 Only a couple of hours left to save \(streakText). Even a README fix counts."
        }
    }
}

@MainActor
final class StreakGuard {
    private let defaults = UserDefaults.standard
    private static let enabledKey = "streakRemindersEnabled"
    private static let dayKey = "streakReminderDay"
    private static let shownKey = "streakReminderShownSlots"
    private static let fedKey = "streakFedDay"

    var isEnabled: Bool {
        get { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    enum Outcome: Equatable {
        case none
        case remind(String)
        case saved(String)
    }

    /// Call after each refresh with today's contribution count.
    func evaluate(todayContributions: Int, streak: Int, now: Date = Date()) -> Outcome {
        let today = Self.dayFormatter.string(from: now)
        if defaults.string(forKey: Self.dayKey) != today {
            defaults.set(today, forKey: Self.dayKey)
            defaults.set([String](), forKey: Self.shownKey)
        }
        var shown = Set(defaults.stringArray(forKey: Self.shownKey) ?? [])

        if todayContributions > 0 {
            guard defaults.string(forKey: Self.fedKey) != today else { return .none }
            defaults.set(today, forKey: Self.fedKey)
            // Only celebrate if Boo had actually been nagging today.
            return shown.isEmpty ? .none : .saved("Streak saved! 🔥 Thanks for the snack — Boo is full and happy.")
        }

        guard isEnabled else { return .none }
        let hour = Calendar.current.component(.hour, from: now)
        guard let slot = StreakReminderSchedule.dueSlot(hour: hour, alreadyShown: shown) else { return .none }
        // Mark this and every earlier slot so waking at 9 p.m. doesn't replay the morning nag.
        for earlier in StreakReminderSchedule.slots where earlier.hour <= slot.hour { shown.insert(earlier.id) }
        defaults.set(Array(shown), forKey: Self.shownKey)
        return .remind(StreakReminderSchedule.message(for: slot, streak: streak))
    }

    func isHungry(todayContributions: Int, now: Date = Date()) -> Bool {
        todayContributions == 0 && Calendar.current.component(.hour, from: now) >= StreakReminderSchedule.slots[0].hour
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension Notification.Name {
    static let commitPetStreakReminder = Notification.Name("CommitPetStreakReminder")
}
