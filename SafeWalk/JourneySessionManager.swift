import Foundation
import CoreLocation
import Combine

final class JourneySessionManager: ObservableObject {

    // MARK: - Published State

    @Published var isJourneyActive = false

    @Published var destinationName = ""

    @Published var destinationLatitude: Double = 0

    @Published var destinationLongitude: Double = 0

    @Published var journeyStartDate: Date?

    @Published var originalPlannedDistance: Double = 0

    @Published var currentPlannedDistance: Double = 0

    @Published var hasBeenRerouted = false

    @Published var rerouteCount = 0

    @Published private(set) var lastUpdatedDate: Date?

    /*
     Emergency state belongs to the journey
     session because it must survive app
     termination, but must never survive after
     the journey itself has ended.
     */

    @Published private(set) var isEmergencyEscalationActive =
        false

    /*
     Persisted arrival state.

     When the user reaches the destination this
     becomes true and remains true until the user
     explicitly finishes the journey.

     This allows the "You've Arrived" completion
     screen to survive app termination.
     */

    @Published private(set) var hasArrived =
        false

    @Published private(set) var journeyID: UUID?

    @Published private(set) var wentOffRoute = false

    @Published private(set) var checkInTriggered = false

    @Published private(set) var checkInExpired = false

    @Published private(set) var needsRerouteAfterRestoration = false


    // MARK: - Computed State

    var destinationCoordinate:
        CLLocationCoordinate2D? {

        guard isJourneyActive else {
            return nil
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
            return nil
        }

        return coordinate
    }


    var hasValidPersistedJourney: Bool {

        guard isJourneyActive else {
            return false
        }

        guard
            !destinationName
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

        static let emergencyEscalation =
            "journeyEmergencyEscalationActive"

        static let arrived =
            "journeyHasArrived"

        static let journeyID =
            "journeyID"

        static let wentOffRoute =
            "journeyWentOffRoute"

        static let checkInTriggered =
            "journeyCheckInTriggered"

        static let checkInExpired =
            "journeyCheckInExpired"

        static let pendingReroute =
            "journeyNeedsRerouteAfterRestoration"
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

        journeyID =
            UUID()

        wentOffRoute =
            false

        checkInTriggered =
            false

        checkInExpired =
            false

        needsRerouteAfterRestoration =
            false


        /*
         A new journey must never inherit
         emergency or arrival state from a
         previous journey.
         */

        isEmergencyEscalationActive =
            false

        hasArrived =
            false


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

        /*
         A completed journey should no longer
         receive navigation updates.
         */

        guard !hasArrived else {
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


    // MARK: - Journey Safety Summary

    func recordOffRoute() {

        guard isJourneyActive, !hasArrived, !wentOffRoute else {
            return
        }

        wentOffRoute = true
        touchSession()
        saveJourney()
    }


    func recordCheckInTriggered() {

        guard isJourneyActive, !hasArrived, !checkInTriggered else {
            return
        }

        checkInTriggered = true
        touchSession()
        saveJourney()
    }


    func recordCheckInExpired() {

        guard isJourneyActive, !hasArrived, !checkInExpired else {
            return
        }

        checkInExpired = true
        touchSession()
        saveJourney()
    }


    func markRerouteNeededAfterRestoration() {

        guard isJourneyActive, !hasArrived else {
            return
        }

        needsRerouteAfterRestoration = true
        touchSession()
        saveJourney()
    }


    func clearPendingReroute() {

        guard needsRerouteAfterRestoration else {
            return
        }

        needsRerouteAfterRestoration = false

        if isJourneyActive {
            touchSession()
            saveJourney()
        } else {
            defaults.removeObject(forKey: Keys.pendingReroute)
        }
    }


    // MARK: - Emergency Escalation

    func activateEmergencyEscalation() {

        guard isJourneyActive else {
            return
        }

        /*
         Once the user has arrived, no new
         emergency escalation should be created.
         */

        guard !hasArrived else {
            return
        }

        guard !isEmergencyEscalationActive else {
            return
        }


        isEmergencyEscalationActive =
            true


        touchSession()

        saveJourney()


    }


    func clearEmergencyEscalation() {

        guard isJourneyActive else {

            isEmergencyEscalationActive =
                false

            defaults.removeObject(
                forKey:
                    Keys.emergencyEscalation
            )

            return
        }


        guard isEmergencyEscalationActive else {
            return
        }


        isEmergencyEscalationActive =
            false


        touchSession()

        saveJourney()


    }


    // MARK: - Arrival

    func markJourneyArrived() {

        guard isJourneyActive else {
            return
        }

        guard !hasArrived else {
            return
        }


        /*
         Persist arrival before any monitoring
         state is cleaned up.
         */

        hasArrived =
            true

        needsRerouteAfterRestoration =
            false


        /*
         Arrival resolves any outstanding
         emergency state for this journey.
         */

        isEmergencyEscalationActive =
            false


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

        /*
         This clears both the active journey and
         its persisted arrival/emergency state.
         */

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

        defaults.set(
            isEmergencyEscalationActive,
            forKey:
                Keys.emergencyEscalation
        )

        defaults.set(
            hasArrived,
            forKey:
                Keys.arrived
        )

        defaults.set(
            journeyID?.uuidString,
            forKey:
                Keys.journeyID
        )

        defaults.set(
            wentOffRoute,
            forKey:
                Keys.wentOffRoute
        )

        defaults.set(
            checkInTriggered,
            forKey:
                Keys.checkInTriggered
        )

        defaults.set(
            checkInExpired,
            forKey:
                Keys.checkInExpired
        )

        defaults.set(
            needsRerouteAfterRestoration,
            forKey:
                Keys.pendingReroute
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

        isEmergencyEscalationActive =
            defaults.bool(
                forKey:
                    Keys.emergencyEscalation
            )

        hasArrived =
            defaults.bool(
                forKey:
                    Keys.arrived
            )

        journeyID =
            defaults.string(forKey: Keys.journeyID)
                .flatMap(UUID.init(uuidString:))

        wentOffRoute =
            defaults.bool(forKey: Keys.wentOffRoute)

        checkInTriggered =
            defaults.bool(forKey: Keys.checkInTriggered)

        checkInExpired =
            defaults.bool(forKey: Keys.checkInExpired)

        needsRerouteAfterRestoration =
            defaults.bool(forKey: Keys.pendingReroute)
    }


    // MARK: - Validate Loaded Journey

    private func validateLoadedJourney() {

        guard isJourneyActive else {

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

        guard
            defaults.object(forKey: Keys.latitude) != nil,
            defaults.object(forKey: Keys.longitude) != nil
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
         A start date significantly in the
         future indicates corrupted persistence.
         */

        if startDate >
            Date()
                .addingTimeInterval(
                    60
                ) {

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
         Arrival and emergency escalation cannot
         logically coexist.

         If an older/corrupted persisted state
         contains both, arrival takes priority.
         */

        if
            hasArrived &&
            isEmergencyEscalationActive {

            isEmergencyEscalationActive =
                false

            saveJourney()
        }

        if hasArrived && needsRerouteAfterRestoration {

            needsRerouteAfterRestoration = false
            saveJourney()
        }

        if journeyID == nil {

            journeyID = UUID()
            saveJourney()
        }


        /*
         Migration for sessions saved before
         lastUpdatedDate existed.
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
        ) != nil ||

        defaults.object(
            forKey:
                Keys.emergencyEscalation
        ) != nil ||

        defaults.object(
            forKey:
                Keys.arrived
        ) != nil ||

        defaults.object(
            forKey:
                Keys.journeyID
        ) != nil ||

        defaults.object(
            forKey:
                Keys.pendingReroute
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

        isEmergencyEscalationActive =
            false

        hasArrived =
            false

        journeyID =
            nil

        wentOffRoute =
            false

        checkInTriggered =
            false

        checkInExpired =
            false

        needsRerouteAfterRestoration =
            false
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

        defaults.removeObject(
            forKey:
                Keys.emergencyEscalation
        )

        defaults.removeObject(
            forKey:
                Keys.arrived
        )

        defaults.removeObject(forKey: Keys.journeyID)
        defaults.removeObject(forKey: Keys.wentOffRoute)
        defaults.removeObject(forKey: Keys.checkInTriggered)
        defaults.removeObject(forKey: Keys.checkInExpired)
        defaults.removeObject(forKey: Keys.pendingReroute)
    }
}
