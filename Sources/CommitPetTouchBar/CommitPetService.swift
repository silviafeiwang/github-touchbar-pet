import Foundation

protocol CommitPetStatsProviding: Sendable {
    func fetch(username: String) async throws -> PetStats
}

struct RemoteSVGStatsProvider: CommitPetStatsProviding {
    private let session: URLSession
    private let parser: CommitPetSVGParser

    init(session: URLSession = .shared, parser: CommitPetSVGParser = .init()) {
        self.session = session
        self.parser = parser
    }

    func fetch(username: String) async throws -> PetStats {
        var components = URLComponents(
            string: "https://raw.githubusercontent.com/\(username)/\(username)/main/commit-pet.svg"
        )!
        components.queryItems = [URLQueryItem(name: "refresh", value: String(Int(Date().timeIntervalSince1970)))]
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try parser.parse(data, username: username)
    }
}
