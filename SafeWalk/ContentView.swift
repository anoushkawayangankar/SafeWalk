import SwiftUI

struct ContentView: View {
    @StateObject private var destinationSearch =
        DestinationSearch()

    @EnvironmentObject var sessionManager:
        JourneySessionManager

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(spacing: 24) {

                    // MARK: - Title

                    VStack(spacing: 8) {

                        Image(systemName: "figure.walk.circle.fill")
                            .font(.system(size: 58))

                        Text("SafeWalk")
                            .font(.largeTitle)
                            .bold()

                        Text("Safer journeys, one walk at a time.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)


                    // MARK: - Active Journey

                    if sessionManager.hasValidPersistedJourney {

                        VStack(spacing: 14) {

                            HStack {

                                Image(systemName: "figure.walk")
                                    .font(.title2)

                                VStack(alignment: .leading, spacing: 4) {

                                    Text("Active SafeWalk")
                                        .font(.headline)

                                    Text(
                                        sessionManager.destinationName
                                    )
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }


                            NavigationLink {

                                JourneyView(
                                    destination:
                                        sessionManager.destinationName
                                )

                            } label: {

                                Label(
                                    "Resume SafeWalk",
                                    systemImage:
                                        "arrow.right.circle.fill"
                                )
                                .frame(
                                    maxWidth: .infinity
                                )
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(
                            Color(.secondarySystemBackground)
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 18
                            )
                        )


                    } else {

                        // MARK: - New Journey

                        VStack(spacing: 14) {

                            Image(
                                systemName:
                                    "location.magnifyingglass"
                            )
                            .font(.system(size: 34))


                            Text("Where are you going?")
                                .font(.title2)
                                .bold()


                            Text(
                                "Search for a destination and SafeWalk will calculate a walking route."
                            )
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)


                            NavigationLink {

                                DestinationSearchView(
                                    destinationSearch:
                                        destinationSearch
                                )

                            } label: {

                                Label(
                                    "Choose Destination",
                                    systemImage:
                                        "magnifyingglass"
                                )
                                .frame(
                                    maxWidth: .infinity
                                )
                            }
                            .buttonStyle(
                                .borderedProminent
                            )
                        }
                        .padding()
                        .background(
                            Color(.secondarySystemBackground)
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 18
                            )
                        )
                    }


                    // MARK: - Safety Settings

                    VStack(spacing: 14) {

                        Text("Safety")
                            .font(.headline)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )


                        NavigationLink {

                            EmergencyContactView()

                        } label: {

                            HStack {

                                Image(
                                    systemName:
                                        "person.crop.circle.badge.plus"
                                )

                                Text(
                                    "Emergency Contact"
                                )

                                Spacer()

                                Image(
                                    systemName:
                                        "chevron.right"
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)
                        .background(
                            Color(.secondarySystemBackground)
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 14
                            )
                        )


                        NavigationLink {

                            JourneyHistoryView()

                        } label: {

                            HStack {

                                Image(
                                    systemName:
                                        "clock.arrow.circlepath"
                                )

                                Text(
                                    "Journey History"
                                )

                                Spacer()

                                Image(
                                    systemName:
                                        "chevron.right"
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)
                        .background(
                            Color(.secondarySystemBackground)
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 14
                            )
                        )
                    }


                    // MARK: - Status

                    VStack(spacing: 8) {

                        Image(
                            systemName:
                                "shield.checkered"
                        )
                        .font(.title2)

                        Text(
                            "SafeWalk uses your location during active journeys to monitor your route and safety."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.top, 10)
                }
                .padding()
            }
            .navigationTitle("SafeWalk")
        }
    }
}


#Preview {

    ContentView()
        .environmentObject(
            JourneySessionManager()
        )
}
