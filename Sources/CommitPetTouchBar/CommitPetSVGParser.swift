import Foundation

enum CommitPetParseError: LocalizedError {
    case invalidUTF8
    case missingField(String)

    var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            "The Commit Pet SVG was not valid UTF-8."
        case .missingField(let field):
            "The Commit Pet SVG did not contain \(field)."
        }
    }
}

struct CommitPetSVGParser: Sendable {
    func parse(_ data: Data, username: String, refreshedAt: Date = Date()) throws -> PetStats {
        guard let svg = String(data: data, encoding: .utf8) else {
            throw CommitPetParseError.invalidUTF8
        }

        let header = try capture(
            #"aria-label="([^"]+) - Lv([0-9]+) ([^"]+)""#,
            in: svg,
            field: "pet name, level, and mood"
        )
        guard header.count == 3, let level = Int(header[1]), let mood = PetMood.parse(header[2]) else {
            throw CommitPetParseError.missingField("valid pet name, level, and mood")
        }

        let streakText = try capture(#"🔥\s*([0-9]+)\s+streak"#, in: svg, field: "streak")[0]
        let todayText = try capture(#"🌱\s*today\s*([0-9]+)"#, in: svg, field: "today count")[0]
        let totalText = try capture(#">\s*([0-9]+)\s+contributions"#, in: svg, field: "total contributions")[0]

        guard let streak = Int(streakText), let todayCount = Int(todayText), let total = Int(totalText) else {
            throw CommitPetParseError.missingField("numeric contribution statistics")
        }

        return PetStats(
            name: decodeEntities(header[0]),
            username: username,
            level: level,
            mood: mood,
            streak: streak,
            todayCount: todayCount,
            total: total,
            refreshedAt: refreshedAt
        )
    }

    private func capture(_ pattern: String, in text: String, field: String) throws -> [String] {
        let expression = try NSRegularExpression(pattern: pattern)
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: fullRange) else {
            throw CommitPetParseError.missingField(field)
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
    }

    private func decodeEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
