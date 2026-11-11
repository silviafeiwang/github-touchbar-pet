import Foundation

enum PetMood: String, Codable, CaseIterable, Sendable {
    case happy
    case content
    case hungry
    case sick

    var displayName: String {
        switch self {
        case .happy: "Happy"
        case .content: "Okay"
        case .hungry: "Hungry"
        case .sick: "Sick"
        }
    }

    var symbol: String {
        switch self {
        case .happy: "✨"
        case .content: "🙂"
        case .hungry: "🍙"
        case .sick: "🤒"
        }
    }

    static func parse(_ value: String) -> PetMood? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "happy": .happy
        case "okay", "content": .content
        case "hungry": .hungry
        case "sick": .sick
        default: nil
        }
    }
}

struct PetStats: Equatable, Codable, Sendable {
    var name: String
    var username: String
    var level: Int
    var mood: PetMood
    var streak: Int
    var todayCount: Int
    var total: Int
    var refreshedAt: Date

    static func placeholder(username: String) -> PetStats {
        PetStats(
            name: "Boo",
            username: username,
            level: 1,
            mood: .content,
            streak: 0,
            todayCount: 0,
            total: 0,
            refreshedAt: .distantPast
        )
    }
}
