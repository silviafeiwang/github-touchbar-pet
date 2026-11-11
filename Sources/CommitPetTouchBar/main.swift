import AppKit

if CommandLine.arguments.contains("--self-test") {
    let html = """
    <td data-date="2026-11-10" id="day-a" data-level="1"></td>
    <td data-date="2026-11-11" id="day-b" data-level="3"></td>
    <td data-date="2026-11-09" id="day-c" data-level="0"></td>
    <tool-tip id="t1" for="day-a" popover="manual">1 contribution on November 10th.</tool-tip>
    <tool-tip id="t2" for="day-b" popover="manual">1,014 contributions on November 11th.</tool-tip>
    <tool-tip id="t3" for="day-c" popover="manual">No contributions on November 9th.</tool-tip>
    """
    let parsed = ContributionCalendar.parsePublicGraph(html)
    precondition(parsed.dailyCounts == ["2026-11-10": 1, "2026-11-11": 1014, "2026-11-09": 0])

    precondition(PetStats.level(forYearlyTotal: 0) == 1)
    precondition(PetStats.level(forYearlyTotal: 80) == 3)
    precondition(PetStats.level(forYearlyTotal: 500) == 6)

    precondition(StreakReminderSchedule.dueSlot(hour: 9, alreadyShown: []) == nil)
    precondition(StreakReminderSchedule.dueSlot(hour: 10, alreadyShown: [])?.id == "morning")
    precondition(StreakReminderSchedule.dueSlot(hour: 14, alreadyShown: ["morning"]) == nil)
    precondition(StreakReminderSchedule.dueSlot(hour: 16, alreadyShown: ["morning"])?.id == "afternoon")
    precondition(StreakReminderSchedule.dueSlot(hour: 23, alreadyShown: [])?.id == "lastCall")
    precondition(StreakReminderSchedule.message(for: StreakReminderSchedule.slots[0], streak: 8).contains("8-day"))
    let cal = Calendar.current
    let now = Date()
    func key(_ offset: Int) -> String { ContributionCalendar.dayKey(cal.date(byAdding: .day, value: -offset, to: now)!) }
    func graph(_ counts: [String: Int]) -> ContributionCalendar { ContributionCalendar(dailyCounts: counts) }
    precondition(graph([key(0): 2, key(1): 1, key(2): 5]).streak(endingAt: now) == 3)
    precondition(graph([key(1): 1, key(2): 5, key(4): 1]).streak(endingAt: now) == 2)
    precondition(graph([key(2): 5]).streak(endingAt: now) == 0)
    precondition(PetStats.from(graph([key(0): 1]), name: "Boo", username: "x", now: now).mood == .happy)
    precondition(PetStats.from(graph([key(5): 1]), name: "Boo", username: "x", now: now).mood == .sick)
    print("CommitPetTouchBar self-test passed")
} else if let index = CommandLine.arguments.firstIndex(of: "--print-stats") {
    // Debug helper: fetch the public contribution graph and print Boo's stats.
    let username = CommandLine.arguments.dropFirst(index + 1).first ?? "silviafeiwang"
    let calendar = try await ContributionCalendarProvider().fetch(username: username)
    let stats = PetStats.from(calendar, name: "Boo", username: username)
    print("Lv\(stats.level) \(stats.mood.displayName) · 🔥\(stats.streak) streak · 🌱\(stats.todayCount) today · \(stats.total) this year")
} else {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
