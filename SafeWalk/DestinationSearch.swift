import Foundation
import MapKit
import Combine

final class DestinationSearch: ObservableObject {

    @Published var searchResults: [MKMapItem] = []
    @Published var selectedDestination: MKMapItem?

    @Published var isSearching = false
    @Published var errorMessage: String?

    func search(for query: String) {

        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedQuery.isEmpty else {
            searchResults = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery

        let search = MKLocalSearch(request: request)

        search.start { response, error in

            DispatchQueue.main.async {

                self.isSearching = false

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.searchResults = []
                    return
                }

                guard let response = response else {
                    self.errorMessage = "No results found."
                    self.searchResults = []
                    return
                }

                self.searchResults = Array(
                    response.mapItems.prefix(10)
                )
            }
        }
    }

    func selectDestination(_ item: MKMapItem) {

        selectedDestination = item
        searchResults = []
        errorMessage = nil
    }

    func clearSelection() {

        selectedDestination = nil
        searchResults = []
        errorMessage = nil
    }
}
