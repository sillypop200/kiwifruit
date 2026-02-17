
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
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            results = try await api.searchBooks(query: query)
        } catch {
            errorMessage = "Failed to search books."
        }
    }
}
