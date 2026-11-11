import Foundation

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
