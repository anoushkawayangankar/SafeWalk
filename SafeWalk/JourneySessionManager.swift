import Foundation
import CoreLocation
import Combine

final class JourneySessionManager:
    ObservableObject {

    // MARK: - Published State

    @Published var isJourneyActive = false

    @Published var destinationName = ""

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

    @Published private(set) var lastUpdatedDate:
        Date?


    // MARK: - Computed State

    var destinationCoordinate:
        CLLocationCoordinate2D? {

        guard isJourneyActive else {
            return nil
        }

        guard
            CLLocationCoordinate2DIsValid(
                CLLocationCoordinate2D(
                    latitude:
                        destinationLatitude,
                    longitude:
                        destinationLongitude
                )
            )
        else {
            return nil
        }

        return CLLocationCoordinate2D(
            latitude:
                destinationLatitude,
            longitude:
                destinationLongitude
        )
    }

    var hasValidPersistedJourney: Bool {

        guard isJourneyActive else {
            return false
        }

        guard !destinationName
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
        else {
            return false
        }

        guard destinationCoordinate != nil else {
            return false
        }

        guard journeyStartDate != nil else {
            return false
        }

        return true
    }


    // MARK: - Storage

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

        static let lastUpdated =
            "journeyLastUpdatedDate"
    }


    // MARK: - Init

    init() {

        loadJourney()

        validateLoadedJourney()
    }


    // MARK: - Start Journey

    func startJourney(
        destination: String,
        coordinate:
            CLLocationCoordinate2D,
        plannedDistance:
            Double = 0
    ) {

        guard
            CLLocationCoordinate2DIsValid(
                coordinate
            )
        else {
            return
        }

        let cleanedName =
            destination
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !cleanedName.isEmpty else {
            return
        }


        isJourneyActive =
            true

        destinationName =
            cleanedName

        destinationLatitude =
            coordinate.latitude

        destinationLongitude =
            coordinate.longitude

        journeyStartDate =
            Date()

        originalPlannedDistance =
            max(
                0,
                plannedDistance
            )

        currentPlannedDistance =
            max(
                0,
                plannedDistance
            )

        hasBeenRerouted =
            false

        rerouteCount =
            0

        touchSession()

        saveJourney()
    }


    // MARK: - Record Reroute

    func recordReroute(
        newPlannedDistance:
            Double
    ) {

        guard isJourneyActive else {
            return
        }

        hasBeenRerouted =
            true

        rerouteCount += 1

        currentPlannedDistance =
            max(
                0,
                newPlannedDistance
            )

        touchSession()

        saveJourney()
    }


    // MARK: - Update Session

    func markSessionActive() {

        guard isJourneyActive else {
            return
        }

        touchSession()

        saveJourney()
    }


    // MARK: - End Journey

    func endJourney() {

        resetPublishedState()

        clearJourney()
    }


    // MARK: - Touch Session

    private func touchSession() {

        lastUpdatedDate =
            Date()
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

        defaults.set(
            lastUpdatedDate,
            forKey:
                Keys.lastUpdated
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

        lastUpdatedDate =
            defaults.object(
                forKey:
                    Keys.lastUpdated
            ) as? Date
    }


    // MARK: - Validate Loaded Journey

    private func validateLoadedJourney() {

        guard isJourneyActive else {

            /*
             If storage says the journey is not
             active, normalize any leftover data.
             */

            if hasStoredJourneyData {

                resetPublishedState()

                clearJourney()
            }

            return
        }


        guard
            !destinationName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
        else {

            invalidatePersistedJourney()

            return
        }


        let coordinate =
            CLLocationCoordinate2D(
                latitude:
                    destinationLatitude,
                longitude:
                    destinationLongitude
            )


        guard
            CLLocationCoordinate2DIsValid(
                coordinate
            )
        else {

            invalidatePersistedJourney()

            return
        }


        guard
            let startDate =
                journeyStartDate
        else {

            invalidatePersistedJourney()

            return
        }


        /*
         A journey start time in the future
         indicates corrupted persistence data.
         */

        if startDate >
            Date()
                .addingTimeInterval(60) {

            invalidatePersistedJourney()

            return
        }


        originalPlannedDistance =
            max(
                0,
                originalPlannedDistance
            )

        currentPlannedDistance =
            max(
                0,
                currentPlannedDistance
            )

        rerouteCount =
            max(
                0,
                rerouteCount
            )


        if rerouteCount == 0 {

            hasBeenRerouted =
                false
        }


        /*
         Existing users may have persisted
         sessions from before lastUpdatedDate
         existed.
         */

        if lastUpdatedDate == nil {

            lastUpdatedDate =
                journeyStartDate

            saveJourney()
        }
    }


    // MARK: - Detect Stored Data

    private var hasStoredJourneyData:
        Bool {

        defaults.object(
            forKey:
                Keys.name
        ) != nil ||

        defaults.object(
            forKey:
                Keys.startDate
        ) != nil ||

        defaults.object(
            forKey:
                Keys.latitude
        ) != nil ||

        defaults.object(
            forKey:
                Keys.longitude
        ) != nil
    }


    // MARK: - Invalidate

    private func invalidatePersistedJourney() {

        resetPublishedState()

        clearJourney()
    }


    // MARK: - Reset State

    private func resetPublishedState() {

        isJourneyActive =
            false

        destinationName =
            ""

        destinationLatitude =
            0

        destinationLongitude =
            0

        journeyStartDate =
            nil

        originalPlannedDistance =
            0

        currentPlannedDistance =
            0

        hasBeenRerouted =
            false

        rerouteCount =
            0

        lastUpdatedDate =
            nil
    }


    // MARK: - Clear Persistence

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

        defaults.removeObject(
            forKey:
                Keys.lastUpdated
        )
    }
}
