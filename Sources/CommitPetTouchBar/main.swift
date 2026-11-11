import AppKit

if CommandLine.arguments.contains("--self-test") {
    let sample = """
    <svg role="img" aria-label="Boo - Lv7 Happy">
      <text>🔥 8 streak　🌱 today 3</text>
      <text>5833 contributions (1y)</text>
    </svg>
    """
    let stats = try CommitPetSVGParser().parse(Data(sample.utf8), username: "silviafeiwang")
    precondition(stats.name == "Boo")
    precondition(stats.level == 7)
    precondition(stats.mood == .happy)
    precondition(stats.streak == 8)
    precondition(stats.todayCount == 3)
    precondition(stats.total == 5833)

    precondition(StreakReminderSchedule.dueSlot(hour: 9, alreadyShown: []) == nil)
    precondition(StreakReminderSchedule.dueSlot(hour: 10, alreadyShown: [])?.id == "morning")
    precondition(StreakReminderSchedule.dueSlot(hour: 14, alreadyShown: ["morning"]) == nil)
    precondition(StreakReminderSchedule.dueSlot(hour: 16, alreadyShown: ["morning"])?.id == "afternoon")
    precondition(StreakReminderSchedule.dueSlot(hour: 23, alreadyShown: [])?.id == "lastCall")
    precondition(StreakReminderSchedule.message(for: StreakReminderSchedule.slots[0], streak: 8).contains("8-day"))
    let cal = Calendar.current
    let now = Date()
    func key(_ offset: Int) -> String { LiveStreak.dayKey(cal.date(byAdding: .day, value: -offset, to: now)!) }
    precondition(LiveStreak.streak(dailyCounts: [key(0): 2, key(1): 1, key(2): 5], today: now) == 3)
    precondition(LiveStreak.streak(dailyCounts: [key(1): 1, key(2): 5, key(4): 1], today: now) == 2)
    precondition(LiveStreak.streak(dailyCounts: [key(2): 5], today: now) == 0)
    print("CommitPetTouchBar self-test passed")
} else {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
