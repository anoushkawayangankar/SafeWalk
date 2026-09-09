import SwiftUI
import MapKit

struct DestinationSearchView: View {

    @StateObject private var destinationSearch =
        DestinationSearch()

    @State private var query = ""

    var body: some View {

        VStack(spacing: 16) {

            // MARK: - Search Field

            HStack {

                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(
                    "Search for a destination",
                    text: $query
                )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

                if !query.isEmpty {

                    Button {

                        query = ""
                        destinationSearch.clearSelection()

                    } label: {

                        Image(
                            systemName: "xmark.circle.fill"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(
                Color(.secondarySystemBackground)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14
                )
            )
            .padding(.horizontal)


            // MARK: - Searching

            if destinationSearch.isSearching {

                ProgressView("Searching...")
            }


            // MARK: - Error

            if let error =
                destinationSearch.errorMessage {

                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }


            // MARK: - Results

            List {

                ForEach(
                    Array(
                        destinationSearch
                            .searchResults
                            .enumerated()
                    ),
                    id: \.offset
                ) { _, item in

                    NavigationLink {
                        
                        JourneyView(
                            destination: item.name ?? query,
                            selectedDestination: item
                        )

                    } label: {

                        VStack(
                            alignment: .leading,
                            spacing: 5
                        ) {

                            Text(
                                item.name
                                    ?? "Unknown Place"
                            )
                            .font(.headline)

                            if let address =
                                formattedAddress(
                                    for: item
                                ) {

                                Text(address)
                                    .font(.caption)
                                    .foregroundStyle(
                                        .secondary
                                    )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
        }

        .navigationTitle(
            "Choose Destination"
        )

        .onChange(of: query) {

            let trimmed =
                query.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard trimmed.count >= 2 else {

                destinationSearch.searchResults = []

                return
            }

            destinationSearch.search(
                for: trimmed
            )
        }
    }


    // MARK: - Address Formatter

    private func formattedAddress(
        for item: MKMapItem
    ) -> String? {

        let placemark = item.placemark

        var parts: [String] = []

        if let subLocality =
            placemark.subLocality {

            parts.append(subLocality)
        }

        if let locality =
            placemark.locality {

            parts.append(locality)
        }

        if let administrativeArea =
            placemark.administrativeArea {

            parts.append(administrativeArea)
        }

        guard !parts.isEmpty else {
            return nil
        }

        return parts.joined(
            separator: ", "
        )
    }
}


#Preview {

    NavigationStack {

        DestinationSearchView()
    }
}
