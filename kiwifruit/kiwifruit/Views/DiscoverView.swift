//
//  DiscoverView.swift
//  kiwifruit
//
//  Created by Savannah Brown on 2/15/26.
//

import SwiftUI

struct DiscoverView: View {
    @Bindable var bookSearchViewModel: BookSearchViewModel

    var body: some View {
        List {
            Section("Search books") {
                HStack(spacing: 12) {
                    TextField("Title, author, or ISBN", text: $bookSearchViewModel.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task { await bookSearchViewModel.submit() }
                        }

                    Button {
                        Task { await bookSearchViewModel.submit() }
                    } label: {
                        Text("Search")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        bookSearchViewModel.isSearching ||
                        bookSearchViewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }

                if bookSearchViewModel.isSearching {
                    ProgressView()
                }

                if let msg = bookSearchViewModel.errorMessage {
                    Text(msg)
                }
            }

            Section("Results") {
                if bookSearchViewModel.results.isEmpty {
                    Text("No results yet.")
                } else {
                    ForEach(bookSearchViewModel.results) { book in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.headline)

                            if let authors = book.authors, !authors.isEmpty {
                                Text(authors.joined(separator: ", "))
                                    .font(.subheadline)
                            }

                            if let isbn13 = book.isbn13, !isbn13.isEmpty {
                                Text("ISBN-13: \(isbn13)")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            Section("Recommendations") {
                Text("Coming soon: recommended books based on your interests.")
            }
        }
        .navigationTitle("Discover")
    }
}
