import SwiftUI
import MapKit

struct DestinationSearchView: View {

    // MARK: - State

    @State private var query = ""

    @ObservedObject var destinationSearch:
        DestinationSearch


    // MARK: - Optional Selection Callback

    var onDestinationSelected:
        ((MKMapItem) -> Void)? = nil


    // MARK: - Body

    var body: some View {

        VStack(spacing: 12) {

            // MARK: Search Field

            HStack(spacing: 8) {

                Image(
                    systemName:
                        "magnifyingglass"
                )
                .foregroundStyle(
                    .secondary
                )


                TextField(
                    "Search destination",
                    text:
                        $query
                )
                .textInputAutocapitalization(
                    .words
                )
                .autocorrectionDisabled()


                if !query.isEmpty {

                    Button {

                        query = ""

                        destinationSearch
                            .clearResults()

                    } label: {

                        Image(
                            systemName:
                                "xmark.circle.fill"
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(
                    cornerRadius: 12
                )
                .fill(
                    Color.secondary
                        .opacity(0.10)
                )
            )


            // MARK: Search Button

            Button {

                destinationSearch
                    .search(
                        for:
                            query
                    )

            } label: {

                HStack {

                    if destinationSearch
                        .isSearching {

                        ProgressView()
                    }


                    Text(
                        destinationSearch
                            .isSearching
                        ? "Searching..."
                        : "Search"
                    )
                }
                .frame(
                    maxWidth:
                        .infinity
                )
            }
            .buttonStyle(
                .borderedProminent
            )
            .disabled(
                destinationSearch
                    .isSearching
            )


            // MARK: Error State

            if let error =
                destinationSearch
                    .errorMessage {

                VStack(spacing: 10) {

                    Image(
                        systemName:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(
                        .orange
                    )


                    Text(error)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                        .multilineTextAlignment(
                            .center
                        )


                    if destinationSearch
                        .canRetry {

                        Button {

                            destinationSearch
                                .retryLastSearch()

                        } label: {

                            Label(
                                "Retry Search",
                                systemImage:
                                    "arrow.clockwise"
                            )
                        }
                        .buttonStyle(
                            .bordered
                        )
                    }
                }
                .padding()
                .frame(
                    maxWidth:
                        .infinity
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: 12
                    )
                    .fill(
                        Color.orange
                            .opacity(0.08)
                    )
                )
            }


            // MARK: Search Results

            if !destinationSearch
                .searchResults
                .isEmpty {

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        8
                ) {

                    Text(
                        "Search Results"
                    )
                    .font(.headline)


                    ForEach(
                        Array(
                            destinationSearch
                                .searchResults
                                .enumerated()
                        ),
                        id:
                            \.offset
                    ) {
                        index,
                        item in

                        Button {

                            destinationSearch
                                .selectDestination(
                                    item
                                )


                            query =
                                item.name ??
                                query


                            onDestinationSelected?(
                                item
                            )

                        } label: {

                            destinationRow(
                                item:
                                    item
                            )
                        }
                        .buttonStyle(
                            .plain
                        )


                        if index <
                            destinationSearch
                                .searchResults
                                .count - 1 {

                            Divider()
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(
                        cornerRadius:
                            14
                    )
                    .fill(
                        Color.secondary
                            .opacity(0.07)
                    )
                )
            }


            // MARK: Selected Destination

            if let selected =
                destinationSearch
                    .selectedDestination {

                selectedDestinationContent(
                    item:
                        selected
                )
            }
        }
    }


    // MARK: - Destination Row

    @ViewBuilder
    private func destinationRow(
        item: MKMapItem
    ) -> some View {

        HStack(
            alignment:
                .top,
            spacing:
                12
        ) {

            Image(
                systemName:
                    "mappin.circle.fill"
            )
            .font(
                .title2
            )
            .foregroundStyle(
                .blue
            )


            VStack(
                alignment:
                    .leading,
                spacing:
                    4
            ) {

                Text(
                    item.name ??
                    "Unknown Destination"
                )
                .font(
                    .headline
                )
                .foregroundStyle(
                    .primary
                )


                if let address =
                    formattedAddress(
                        for:
                            item
                    ) {

                    Text(address)
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .multilineTextAlignment(
                            .leading
                        )
                }
            }


            Spacer()


            Image(
                systemName:
                    "chevron.right"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )
        }
        .contentShape(
            Rectangle()
        )
        .padding(
            .vertical,
            6
        )
    }


    // MARK: - Selected Destination

    @ViewBuilder
    private func selectedDestinationContent(
        item: MKMapItem
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                8
        ) {

            Label(
                "Selected Destination",
                systemImage:
                    "checkmark.circle.fill"
            )
            .font(
                .headline
            )
            .foregroundStyle(
                .green
            )


            Text(
                item.name ??
                "Destination"
            )
            .font(
                .headline
            )


            if let address =
                formattedAddress(
                    for:
                        item
                ) {

                Text(address)
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
            }


            Button(
                "Change Destination"
            ) {

                destinationSearch
                    .clearSelection()

                query = ""
            }
            .buttonStyle(
                .bordered
            )
        }
        .padding()
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius:
                    14
            )
            .fill(
                Color.green
                    .opacity(0.08)
            )
        )
    }


    // MARK: - Address

    private func formattedAddress(
        for item: MKMapItem
    ) -> String? {

        if #available(
            iOS 26.0,
            *
        ) {

            return item
                .address?
                .fullAddress

        } else {

            let placemark =
                item.placemark


            let components: [String?] = [
                placemark.name,
                placemark.locality,
                placemark.administrativeArea,
                placemark.country
            ]


            let address =
                components
                    .compactMap { $0 }
                    .filter {
                        !$0.isEmpty
                    }
                    .joined(
                        separator:
                            ", "
                    )


            return address.isEmpty
                ? nil
                : address
        }
    }
}


// MARK: - Preview

#Preview {

    DestinationSearchView(
        destinationSearch:
            DestinationSearch()
    )
    .padding()
}
