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
    print("CommitPetTouchBar self-test passed")
} else {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
