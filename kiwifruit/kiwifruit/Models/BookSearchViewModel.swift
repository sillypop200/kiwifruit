
import Foundation
import Observation

@Observable
final class BookSearchViewModel {
    var query: String = ""
    var results: [BookSearchResult] = []
    var isSearching: Bool = false
    var errorMessage: String?

    private let api: APIClientProtocol

    init(api: APIClientProtocol) {
        self.api = api
    }

    func submit() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            results = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            results = try await api.searchBooks(query: q)
        } catch {
            results = []
            errorMessage = "Search failed. Please try again."
        }
    }
}
