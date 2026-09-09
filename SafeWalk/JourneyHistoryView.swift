import SwiftUI

struct JourneyHistoryView: View {

    @StateObject private var historyManager =
        JourneyHistoryManager()

    var body: some View {

        List {

            // MARK: - Empty History

            if historyManager.journeys.isEmpty {

                VStack(spacing: 12) {

                    Image(
                        systemName: "clock.arrow.circlepath"
                    )
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                    Text("No Journeys Yet")
                        .font(.headline)

                    Text(
                        "Your completed SafeWalk journeys will appear here."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .frame(
                    maxWidth: .infinity
                )
                .padding()

            } else {

                // MARK: - Journey Records

                ForEach(
                    historyManager.journeys
                ) { journey in

                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {

                        // MARK: Destination

                        Text(
                            journey.destination
                        )
                        .font(.headline)


                        // MARK: Date

                        Text(
                            journey.startDate.formatted(
                                date: .abbreviated,
                                time: .shortened
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)


                        Divider()


                        // MARK: Journey Information

                        HStack {

                            Label(
                                "\(journey.durationMinutes) min",
                                systemImage: "clock"
                            )

                            Spacer()

                            Label(
                                String(
                                    format: "%.2f km",
                                    journey.distanceKilometres
                                ),
                                systemImage: "figure.walk"
                            )
                        }
                        .font(.caption)


                        // MARK: Completion Status

                        if journey.completedSuccessfully {

                            Label(
                                "Arrived safely",
                                systemImage:
                                    "checkmark.circle.fill"
                            )
                            .foregroundStyle(.green)

                        } else {

                            Label(
                                "Journey ended manually",
                                systemImage:
                                    "xmark.circle"
                            )
                            .foregroundStyle(.secondary)
                        }


                        // MARK: Safety Events

                        if journey.wentOffRoute {

                            Label(
                                "Went off route",
                                systemImage:
                                    "exclamationmark.triangle.fill"
                            )
                            .foregroundStyle(.orange)
                        }


                        if journey.checkInTriggered {

                            Label(
                                "Safety check-in triggered",
                                systemImage:
                                    "bell.fill"
                            )
                            .foregroundStyle(.secondary)
                        }


                        if journey.checkInExpired {

                            Label(
                                "Safety check-in expired",
                                systemImage:
                                    "exclamationmark.circle.fill"
                            )
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(
                        .vertical,
                        8
                    )
                }
                .onDelete(
                    perform:
                        historyManager
                            .deleteJourney
                )
            }
        }
        .navigationTitle(
            "Journey History"
        )
        .toolbar {

            if !historyManager
                .journeys
                .isEmpty {

                EditButton()
            }
        }
    }
}


#Preview {

    NavigationStack {

        JourneyHistoryView()
    }
}
