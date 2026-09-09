import Foundation
import MapKit
import Combine

final class DestinationSearch: ObservableObject {

    // MARK: - Published State

    @Published private(set) var searchResults: [MKMapItem] = []

    @Published var selectedDestination: MKMapItem?

    @Published private(set) var isSearching = false

    @Published private(set) var errorMessage: String?

    @Published private(set) var canRetry = false


    // MARK: - Active Search

    private var activeSearch: MKLocalSearch?


    // MARK: - Retry State

    private var lastQuery: String?


    // MARK: - Search

    func search(
        for query: String
    ) {

        let trimmedQuery =
            query.trimmingCharacters(
                in: .whitespacesAndNewlines
            )


        // MARK: Empty Query

        guard !trimmedQuery.isEmpty else {

            cancelSearch()

            searchResults = []

            errorMessage =
                "Enter a destination to search."

            canRetry =
                false

            return
        }


        // Save query so Retry Search works.

        lastQuery =
            trimmedQuery


        // Cancel old search if one exists.

        activeSearch?
            .cancel()

        activeSearch =
            nil


        isSearching =
            true

        errorMessage =
            nil

        canRetry =
            false


        // MARK: Build Request

        let request =
            MKLocalSearch.Request()

        request.naturalLanguageQuery =
            trimmedQuery


        let search =
            MKLocalSearch(
                request:
                    request
            )


        activeSearch =
            search


        // MARK: Start Search

        search.start {
            [weak self, weak search]
            response,
            error in

            DispatchQueue.main.async {

                guard let self else {
                    return
                }


                /*
                 Ignore the result if another
                 search has replaced this one.
                 */

                guard
                    let search,
                    self.activeSearch === search
                else {
                    return
                }


                self.activeSearch =
                    nil

                self.isSearching =
                    false


                // MARK: Search Error

                if let error {

                    self.handleSearchError(
                        error
                    )

                    return
                }


                // MARK: Missing Response

                guard let response else {

                    self.searchResults =
                        []

                    self.errorMessage =
                        "SafeWalk couldn't search for that destination. Please try again."

                    self.canRetry =
                        true

                    return
                }


                // MARK: Results

                let results =
                    Array(
                        response
                            .mapItems
                            .prefix(10)
                    )


                // MARK: No Results

                guard !results.isEmpty else {

                    self.searchResults =
                        []

                    self.errorMessage =
                        """
                        No destinations were found for "\(trimmedQuery)". \
                        Try a more specific place name or address.
                        """

                    self.canRetry =
                        true

                    return
                }


                // MARK: Success

                self.searchResults =
                    results

                self.errorMessage =
                    nil

                self.canRetry =
                    false
            }
        }
    }


    // MARK: - Retry Search

    func retryLastSearch() {

        guard !isSearching else {
            return
        }


        guard
            let lastQuery,
            !lastQuery.isEmpty
        else {

            errorMessage =
                "There is no previous destination search to retry."

            canRetry =
                false

            return
        }


        search(
            for:
                lastQuery
        )
    }


    // MARK: - Select Destination

    func selectDestination(
        _ item: MKMapItem
    ) {

        activeSearch?
            .cancel()

        activeSearch =
            nil


        selectedDestination =
            item

        searchResults =
            []

        errorMessage =
            nil

        canRetry =
            false

        isSearching =
            false
    }


    // MARK: - Clear Results

    func clearResults() {

        activeSearch?
            .cancel()

        activeSearch =
            nil


        searchResults =
            []

        errorMessage =
            nil

        canRetry =
            false

        isSearching =
            false
    }


    // MARK: - Clear Error

    func clearError() {

        errorMessage =
            nil

        canRetry =
            false
    }


    // MARK: - Cancel Search

    func cancelSearch() {

        activeSearch?
            .cancel()

        activeSearch =
            nil

        isSearching =
            false
    }


    // MARK: - Clear Selection

    func clearSelection() {

        activeSearch?
            .cancel()

        activeSearch =
            nil


        selectedDestination =
            nil

        searchResults =
            []

        errorMessage =
            nil

        canRetry =
            false

        isSearching =
            false

        lastQuery =
            nil
    }


    // MARK: - Search Error Handling

    private func handleSearchError(
        _ error: Error
    ) {

        let nsError =
            error as NSError


        searchResults =
            []

        isSearching =
            false

        canRetry =
            true


        // MARK: Network Errors

        if nsError.domain ==
            NSURLErrorDomain {

            switch nsError.code {

            case NSURLErrorNotConnectedToInternet:

                errorMessage =
                    """
                    You appear to be offline. \
                    Connect to the internet and retry the destination search.
                    """


            case NSURLErrorTimedOut:

                errorMessage =
                    """
                    The destination search timed out. \
                    Check your connection and try again.
                    """


            case NSURLErrorNetworkConnectionLost:

                errorMessage =
                    """
                    Your internet connection was interrupted \
                    while SafeWalk was searching for the destination.
                    """


            default:

                errorMessage =
                    """
                    SafeWalk couldn't reach the destination search service. \
                    Check your connection and try again.
                    """
            }


            return
        }


        // MARK: MapKit Errors

        if nsError.domain ==
            MKError.errorDomain {

            let code =
                UInt(nsError.code)


            switch code {

            case MKError.Code
                .placemarkNotFound
                .rawValue:

                errorMessage =
                    """
                    SafeWalk couldn't identify that destination. \
                    Try a more specific place name or address.
                    """


            case MKError.Code
                .loadingThrottled
                .rawValue:

                errorMessage =
                    """
                    Too many destination searches were made in a short time. \
                    Wait a moment and try again.
                    """


            case MKError.Code
                .serverFailure
                .rawValue:

                errorMessage =
                    """
                    Apple's location search service is temporarily unavailable. \
                    Please try again shortly.
                    """


            default:

                errorMessage =
                    """
                    SafeWalk couldn't search for that destination. \
                    Please try again.
                    """
            }


            return
        }


        // MARK: Unknown Error

        errorMessage =
            """
            SafeWalk couldn't search for that destination. \
            Please try again.
            """
    }
}
