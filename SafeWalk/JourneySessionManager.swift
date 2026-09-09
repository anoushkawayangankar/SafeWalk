import Foundation
import CoreLocation
import Combine

final class JourneySessionManager:
    ObservableObject {

    @Published var isJourneyActive =
        false

    @Published var destinationName =
        ""

    @Published var destinationLatitude:
        Double = 0

    @Published var destinationLongitude:
        Double = 0

    @Published var journeyStartDate:
        Date?

    @Published var originalPlannedDistance:
        Double = 0

    @Published var currentPlannedDistance:
        Double = 0

    @Published var hasBeenRerouted =
        false

    @Published var rerouteCount =
        0


    private let defaults =
        UserDefaults.standard


    private enum Keys {

        static let active =
            "isJourneyActive"

        static let name =
            "savedDestination"

        static let latitude =
            "savedDestinationLatitude"

        static let longitude =
            "savedDestinationLongitude"

        static let startDate =
            "journeyStartDate"

        static let originalDistance =
            "originalPlannedDistance"

        static let currentDistance =
            "currentPlannedDistance"

        static let rerouted =
            "hasBeenRerouted"

        static let rerouteCount =
            "rerouteCount"
    }


    init() {
        loadJourney()
    }


    // MARK: - Start

    func startJourney(
        destination: String,
        coordinate:
            CLLocationCoordinate2D,
        plannedDistance: Double = 0
    ) {

        isJourneyActive = true

        destinationName =
            destination

        destinationLatitude =
            coordinate.latitude

        destinationLongitude =
            coordinate.longitude

        journeyStartDate =
            Date()

        originalPlannedDistance =
            plannedDistance

        currentPlannedDistance =
            plannedDistance

        hasBeenRerouted = false

        rerouteCount = 0

        saveJourney()
    }


    // MARK: - Reroute

    func recordReroute(
        newPlannedDistance: Double
    ) {

        guard isJourneyActive else {
            return
        }

        hasBeenRerouted = true

        rerouteCount += 1

        currentPlannedDistance =
            newPlannedDistance

        saveJourney()
    }


    // MARK: - End

    func endJourney() {

        isJourneyActive = false

        destinationName = ""

        destinationLatitude = 0
        destinationLongitude = 0

        journeyStartDate = nil

        originalPlannedDistance = 0

        currentPlannedDistance = 0

        hasBeenRerouted = false

        rerouteCount = 0

        clearJourney()
    }


    // MARK: - Save

    private func saveJourney() {

        defaults.set(
            isJourneyActive,
            forKey:
                Keys.active
        )

        defaults.set(
            destinationName,
            forKey:
                Keys.name
        )

        defaults.set(
            destinationLatitude,
            forKey:
                Keys.latitude
        )

        defaults.set(
            destinationLongitude,
            forKey:
                Keys.longitude
        )

        defaults.set(
            journeyStartDate,
            forKey:
                Keys.startDate
        )

        defaults.set(
            originalPlannedDistance,
            forKey:
                Keys.originalDistance
        )

        defaults.set(
            currentPlannedDistance,
            forKey:
                Keys.currentDistance
        )

        defaults.set(
            hasBeenRerouted,
            forKey:
                Keys.rerouted
        )

        defaults.set(
            rerouteCount,
            forKey:
                Keys.rerouteCount
        )
    }


    // MARK: - Load

    private func loadJourney() {

        isJourneyActive =
            defaults.bool(
                forKey:
                    Keys.active
            )

        destinationName =
            defaults.string(
                forKey:
                    Keys.name
            ) ?? ""

        destinationLatitude =
            defaults.double(
                forKey:
                    Keys.latitude
            )

        destinationLongitude =
            defaults.double(
                forKey:
                    Keys.longitude
            )

        journeyStartDate =
            defaults.object(
                forKey:
                    Keys.startDate
            ) as? Date

        originalPlannedDistance =
            defaults.double(
                forKey:
                    Keys.originalDistance
            )

        currentPlannedDistance =
            defaults.double(
                forKey:
                    Keys.currentDistance
            )

        hasBeenRerouted =
            defaults.bool(
                forKey:
                    Keys.rerouted
            )

        rerouteCount =
            defaults.integer(
                forKey:
                    Keys.rerouteCount
            )

        if isJourneyActive {

            if destinationName.isEmpty ||
                (
                    destinationLatitude == 0 &&
                    destinationLongitude == 0
                ) {

                endJourney()
            }
        }
    }


    // MARK: - Clear

    private func clearJourney() {

        defaults.removeObject(
            forKey:
                Keys.active
        )

        defaults.removeObject(
            forKey:
                Keys.name
        )

        defaults.removeObject(
            forKey:
                Keys.latitude
        )

        defaults.removeObject(
            forKey:
                Keys.longitude
        )

        defaults.removeObject(
            forKey:
                Keys.startDate
        )

        defaults.removeObject(
            forKey:
                Keys.originalDistance
        )

        defaults.removeObject(
            forKey:
                Keys.currentDistance
        )

        defaults.removeObject(
            forKey:
                Keys.rerouted
        )

        defaults.removeObject(
            forKey:
                Keys.rerouteCount
        )
    }
}
