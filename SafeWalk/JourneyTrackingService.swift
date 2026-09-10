import Foundation
import CoreLocation
import MapKit
import Combine
import UIKit

final class JourneyTrackingService: ObservableObject {

    // MARK: - Session

    private let sessionManager: JourneySessionManager


    // MARK: - Managers

    let locationManager = LocationManager()
    let journeyMonitor = JourneyMonitor()
    let checkInManager = CheckInManager()
    let periodicCheckInManager = PeriodicCheckInManager()
    let progressManager = JourneyProgressManager()

    private let rerouteManager = RouteManager()


    // MARK: - Journey State

    @Published var route: MKRoute?

    @Published var destinationCoordinate:
        CLLocationCoordinate2D?

    @Published var isTracking = false

    @Published var isEmergencyEscalationActive = false


    // MARK: - Reroute State

    @Published private(set) var isRerouting = false

    @Published private(set) var rerouteVersion = 0

    @Published private(set) var rerouteErrorMessage:
        String?

    @Published private(set) var canRetryReroute = false


    // MARK: - Retry State

    private var lastRerouteStart:
        CLLocationCoordinate2D?

    private var lastRerouteDestination:
        CLLocationCoordinate2D?


    // MARK: - Combine

    private var cancellables =
        Set<AnyCancellable>()


    // MARK: - Init

    init(
        sessionManager: JourneySessionManager
    ) {

        self.sessionManager =
            sessionManager


        /*
         Manager properties restore their own
         persisted state before this initializer
         runs. Clear safety runtime immediately for
         an arrived or invalid session so opening
         the app cannot restart a countdown while
         the completion card is still on screen.
         */

        if
            sessionManager.hasArrived ||
            !sessionManager.hasValidPersistedJourney {

            checkInManager.reset()
            periodicCheckInManager.stop()

            NotificationManager.shared
                .cancelPendingMissedCheckInNotification()

            locationManager.stopUpdatingLocation()
        }

        observeManagerChanges()

        connectLocationUpdates()

        observeCheckInState()

        observeJourneySafetyEvents()

        observeArrivalState()

        observeNotificationActions()

        observeAppLifecycle()
    }


    // MARK: - Forward Manager Changes

    private func observeManagerChanges() {

        let publishers = [

            locationManager
                .objectWillChange
                .eraseToAnyPublisher(),

            journeyMonitor
                .objectWillChange
                .eraseToAnyPublisher(),

            checkInManager
                .objectWillChange
                .eraseToAnyPublisher(),

            periodicCheckInManager
                .objectWillChange
                .eraseToAnyPublisher(),

            progressManager
                .objectWillChange
                .eraseToAnyPublisher()
        ]


        for publisher in publishers {

            publisher
                .sink { [weak self] _ in

                    DispatchQueue.main.async {

                        self?
                            .objectWillChange
                            .send()
                    }
                }
                .store(
                    in: &cancellables
                )
        }
    }


    // MARK: - Location Connection

    private func connectLocationUpdates() {

        locationManager
            .onLocationUpdate = {
                [weak self] location in

                guard let self else {
                    return
                }

                self.processLocation(
                    location
                )
            }
    }


    // MARK: - Process Location

    private func processLocation(
        _ location: CLLocation
    ) {

        guard
            isTracking,
            !sessionManager.hasArrived,
            let destination =
                destinationCoordinate
        else {
            return
        }


        if
            isRerouting ||
            checkInManager.didExpire ||
            isEmergencyEscalationActive {

            /*
             Keep arrival detection active while
             suppressing new off-route events.
             */

            journeyMonitor
                .processArrival(
                    location
                )

        } else {

            journeyMonitor
                .processLocation(
                    location
                )
        }


        /*
         Persist arrival in the same location
         callback that detects it. The observer
         below performs the remaining cleanup.
         */

        if journeyMonitor.hasArrived {

            sessionManager
                .markJourneyArrived()
        }


        /*
         Arrival may have been detected by
         processLocation above.

         Do not continue progress processing once
         the journey has transitioned to arrived.
         */

        guard !sessionManager.hasArrived else {
            return
        }


        progressManager
            .updateProgress(
                userLocation:
                    location.coordinate,

                destination:
                    destination
            )
    }


    // MARK: - Check-In State

    private func observeCheckInState() {

        checkInManager
            .$didExpire
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink {
                [weak self] expired in

                guard let self else {
                    return
                }

                guard
                    self.isTracking,
                    !self.sessionManager.hasArrived
                else {
                    return
                }


                if expired {

                    self
                        .isEmergencyEscalationActive =
                        true


                    self.sessionManager
                        .activateEmergencyEscalation()

                    self.sessionManager
                        .recordCheckInExpired()

                } else {

                    if self
                        .isEmergencyEscalationActive {

                        self
                            .isEmergencyEscalationActive =
                            false


                        self.sessionManager
                            .clearEmergencyEscalation()
                    }
                }
            }
            .store(
                in: &cancellables
            )
    }


    private func observeJourneySafetyEvents() {

        journeyMonitor.$isOffRoute
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOffRoute in
                guard let self, self.isTracking, isOffRoute else {
                    return
                }

                self.sessionManager.recordOffRoute()
            }
            .store(in: &cancellables)

        checkInManager.$isCheckInActive
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                guard let self, self.isTracking, isActive else {
                    return
                }

                self.sessionManager.recordCheckInTriggered()
                self.scheduleMissedCheckInNotification()
            }
            .store(in: &cancellables)
    }


    // MARK: - Arrival State

    private func observeArrivalState() {

        journeyMonitor
            .$hasArrived
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink {
                [weak self] arrived in

                guard let self else {
                    return
                }

                guard
                    self.isTracking,
                    arrived
                else {
                    return
                }


                /*
                 Persist arrival FIRST.

                 This must happen before timers,
                 monitoring or emergency state are
                 cleaned up so arrival survives an
                 app termination at this point.
                 */

                self.sessionManager
                    .markJourneyArrived()


                /*
                 Arrival resolves all outstanding
                 safety countdown state.
                 */

                self.checkInManager
                    .reset()

                NotificationManager.shared
                    .cancelPendingMissedCheckInNotification()


                self.periodicCheckInManager
                    .stop()


                self
                    .isEmergencyEscalationActive =
                    false


                self.sessionManager
                    .clearEmergencyEscalation()


                /*
                 No reroute should remain active
                 after arrival.
                 */

                self.isRerouting =
                    false


                self.rerouteManager
                    .cancelRouteCalculation()


                self.clearRerouteError()


                self.lastRerouteStart =
                    nil


                self.lastRerouteDestination =
                    nil


                /*
                 Safety monitoring is no longer
                 needed after reaching the
                 destination.

                 We intentionally keep the route
                 and destination in memory so the
                 completion UI can still display
                 journey information.
                 */

                self.journeyMonitor
                    .stopMonitoring()


                /*
                 Stop continuous GPS updates once
                 arrival has been persisted.

                 The persisted JourneySession stays
                 active until the user presses
                 Finish Journey.
                 */

                self.locationManager
                    .stopUpdatingLocation()


                /*
                 Tracking becomes false because
                 active safety monitoring has now
                 finished.

                 The journey session itself remains
                 active until Finish Journey.
                 */

                self.isTracking =
                    false


            }
            .store(
                in: &cancellables
            )
    }


    // MARK: - Notification Actions

    private func observeNotificationActions() {

        NotificationDelegate
            .shared
            .userConfirmedSafe
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notificationJourneyID in

                guard let self else {
                    return
                }


                /*
                 Ignore stale notification actions
                 when there is no active safety
                 tracking.
                 */

                guard
                    self.sessionManager.hasValidPersistedJourney,
                    !self.sessionManager.hasArrived,
                    let currentJourneyID = self.sessionManager.journeyID,
                    notificationJourneyID == currentJourneyID
                else {
                    return
                }


                /*
                 Only accept the notification
                 action when some safety event is
                 actually unresolved.
                 */

                guard
                    self
                        .checkInManager
                        .isCheckInActive ||

                    self
                        .checkInManager
                        .didExpire ||

                    self
                        .isEmergencyEscalationActive
                else {
                    return
                }


                self.confirmSafe()
            }
            .store(
                in: &cancellables
            )
    }


    // MARK: - Prepare Location

    func prepareLocation() {

        connectLocationUpdates()


        locationManager
            .requestLocationPermission()


        if locationManager
            .hasLocationPermission {

            locationManager
                .startUpdatingLocation()
        }
    }


    // MARK: - Start Tracking

    func startTracking(
        route: MKRoute,
        destination:
            CLLocationCoordinate2D
    ) {

        /*
         A new tracking session should never be
         started for a journey that has already
         arrived.
         */

        guard !sessionManager.hasArrived else {
            return
        }


        /*
         A brand-new journey must begin with
         completely fresh safety state.
         */

        checkInManager
            .reset()


        periodicCheckInManager
            .stop()


        sessionManager
            .clearEmergencyEscalation()


        isEmergencyEscalationActive =
            false


        // Reset rerouting state.

        isRerouting =
            false

        rerouteVersion =
            0

        clearRerouteError()


        lastRerouteStart =
            nil

        lastRerouteDestination =
            nil


        // Store route state.

        self.route =
            route


        destinationCoordinate =
            destination


        isTracking =
            true


        // Start progress.

        progressManager
            .startJourney(
                route:
                    route
            )


        // Start route monitoring.

        journeyMonitor
            .startMonitoring(
                route:
                    route,

                destination:
                    destination,

                checkInManager:
                    checkInManager,

                journeyID:
                    sessionManager.journeyID
            )


        // Start GPS.

        prepareLocation()


        // Start periodic safety checks.

        startPeriodicCheckIns()


        // Enable background tracking when allowed.

        if locationManager
            .authorizationStatus ==
            .authorizedAlways {

            locationManager
                .startBackgroundTracking()

        } else {

            locationManager
                .requestBackgroundLocationPermission()
        }


        // Process currently known GPS immediately.

        if let current =
            locationManager.location {

            journeyMonitor
                .processLocation(
                    current
                )


            /*
             Arrival could have been detected by
             the immediate location processing.
             */

            if !sessionManager.hasArrived {

                progressManager
                    .updateProgress(
                        userLocation:
                            current.coordinate,

                        destination:
                            destination
                    )
            }
        }
    }


    // MARK: - Restore Tracking

    func restoreTracking(
        route: MKRoute,
        destination:
            CLLocationCoordinate2D
    ) {

        /*
         CRITICAL COLD-LAUNCH CASE:

         Arrival may have been persisted before
         SafeWalk was terminated.

         Do not restart route monitoring, periodic
         check-ins, emergency logic or background
         location for an already-arrived journey.

         Keep the route and destination available
         so JourneyView can display its completion
         screen.
         */

        if sessionManager.hasArrived {

            self.route =
                route


            destinationCoordinate =
                destination


            isTracking =
                false


            isRerouting =
                false


            rerouteVersion =
                0


            clearRerouteError()


            lastRerouteStart =
                nil


            lastRerouteDestination =
                nil


            rerouteManager
                .cancelRouteCalculation()


            checkInManager
                .reset()

            NotificationManager.shared
                .cancelPendingMissedCheckInNotification()


            periodicCheckInManager
                .stop()


            journeyMonitor
                .stopMonitoring()


            progressManager
                .startJourney(
                    route:
                        route
                )


            isEmergencyEscalationActive =
                false


            sessionManager
                .clearEmergencyEscalation()


            locationManager
                .stopUpdatingLocation()


            return
        }


        /*
         IMPORTANT:

         Do not reset CheckInManager or
         PeriodicCheckInManager here.

         They may already contain persisted state
         restored from UserDefaults.
         */

        self.route =
            route


        destinationCoordinate =
            destination


        isTracking =
            true


        isRerouting =
            false


        clearRerouteError()


        lastRerouteStart =
            nil

        lastRerouteDestination =
            nil


        // Restore safety timer state.

        checkInManager
            .appDidBecomeActive()

        if checkInManager.isCheckInActive {
            sessionManager.recordCheckInTriggered()
            scheduleMissedCheckInNotification()
        }

        if checkInManager.didExpire {
            sessionManager.recordCheckInExpired()
        }


        // Restore emergency state.

        synchronizeRestoredSafetyState()


        // Restore progress.

        progressManager
            .startJourney(
                route:
                    route
            )


        // Restore route monitoring.

        journeyMonitor
            .startMonitoring(
                route:
                    route,

                destination:
                    destination,

                checkInManager:
                    checkInManager,

                journeyID:
                    sessionManager.journeyID
            )


        // Restore GPS.

        prepareLocation()


        /*
         Always reconnect the periodic callback.

         If PeriodicCheckInManager already has a
         persisted deadline, its start() function
         continues that deadline instead of
         creating a fresh 60-second cycle.
         */

        startPeriodicCheckIns()


        // Restore background tracking.

        if locationManager
            .authorizationStatus ==
            .authorizedAlways {

            locationManager
                .startBackgroundTracking()
        }


        /*
         Do not immediately trigger route safety
         logic if we're restoring into an active
         or expired check-in.
         */

        if
            !checkInManager.isCheckInActive,
            !checkInManager.didExpire,
            !isEmergencyEscalationActive,
            !sessionManager.hasArrived,
            let current =
                locationManager.location {

            journeyMonitor
                .processLocation(
                    current
                )


            if !sessionManager.hasArrived {

                progressManager
                    .updateProgress(
                        userLocation:
                            current.coordinate,

                        destination:
                            destination
                    )
            }
        }

        if sessionManager.needsRerouteAfterRestoration {
            beginReroute()
        }
    }


    // MARK: - Restore Safety State

    private func synchronizeRestoredSafetyState() {

        /*
         An arrived journey must never restore
         emergency state.
         */

        if sessionManager.hasArrived {

            isEmergencyEscalationActive =
                false


            sessionManager
                .clearEmergencyEscalation()


            return
        }


        /*
         Priority 1:
         check-in expired while SafeWalk was not
         active.
         */

        if checkInManager.didExpire {

            isEmergencyEscalationActive =
                true


            sessionManager
                .activateEmergencyEscalation()


            return
        }


        /*
         Priority 2:
         emergency state was already persisted in
         the journey session.
         */

        if sessionManager
            .isEmergencyEscalationActive {

            isEmergencyEscalationActive =
                true

            return
        }


        /*
         Priority 3:
         an active countdown is being restored.
         This is not yet an emergency.
         */

        if checkInManager
            .isCheckInActive {

            isEmergencyEscalationActive =
                false

            return
        }


        isEmergencyEscalationActive =
            false


        sessionManager
            .clearEmergencyEscalation()
    }


    // MARK: - Periodic Check-Ins

    private func startPeriodicCheckIns() {

        guard
            isTracking,
            !sessionManager.hasArrived
        else {
            return
        }


        periodicCheckInManager
            .recoverInterruptedTriggerIfNeeded(
                hasUnresolvedCheckIn:
                    checkInManager.isCheckInActive ||
                    checkInManager.didExpire ||
                    isEmergencyEscalationActive
            )

        periodicCheckInManager
            .start {
                [weak self] in

                guard let self else {
                    return
                }


                guard
                    self.isTracking,
                    !self.sessionManager.hasArrived
                else {
                    return
                }


                guard
                    !self
                        .journeyMonitor
                        .hasArrived
                else {
                    return
                }


                /*
                 Never create another check-in on
                 top of an unresolved one.
                 */

                guard
                    !self
                        .checkInManager
                        .isCheckInActive,

                    !self
                        .checkInManager
                        .didExpire,

                    !self
                        .isEmergencyEscalationActive
                else {
                    return
                }


                self.checkInManager
                    .startCheckIn(
                        reason:
                            .periodic
                    )


                NotificationManager
                    .shared
                    .sendPeriodicCheckInNotification(
                        journeyID:
                            self.sessionManager.journeyID
                    )
            }
    }


    // MARK: - Confirm Safe

    func confirmSafe() {

        guard
            sessionManager.hasValidPersistedJourney,
            !sessionManager.hasArrived,
            checkInManager.isCheckInActive ||
                checkInManager.didExpire ||
                isEmergencyEscalationActive
        else {
            return
        }


        /*
         Capture reason BEFORE confirmSafe clears
         the reason value.
         */

        let reason =
            checkInManager.reason


        checkInManager
            .confirmSafe()

        NotificationManager.shared
            .cancelPendingMissedCheckInNotification()


        isEmergencyEscalationActive =
            false


        sessionManager
            .clearEmergencyEscalation()


        /*
         Previous safety event is complete.

         A new periodic cycle can now begin.
         */

        if isTracking {
            periodicCheckInManager
                .checkInCompleted()
        } else {
            periodicCheckInManager
                .stop()
        }


        /*
         Only off-route confirmation should
         trigger navigation rerouting.
         */

        guard reason == .offRoute else {
            return
        }

        sessionManager
            .markRerouteNeededAfterRestoration()

        if isTracking {
            beginReroute()
        }
    }


    // MARK: - Begin Reroute

    private func beginReroute() {

        guard
            isTracking,
            !sessionManager.hasArrived,
            !isRerouting
        else {
            return
        }


        guard
            let current =
                locationManager.location,

            let destination =
                destinationCoordinate
        else {

            rerouteErrorMessage =
                "SafeWalk couldn't update your route because your current location is unavailable."


            canRetryReroute =
                true


            return
        }


        lastRerouteStart =
            current.coordinate


        lastRerouteDestination =
            destination


        performReroute(
            from:
                current.coordinate,

            to:
                destination
        )
    }


    // MARK: - Perform Reroute

    private func performReroute(
        from start:
            CLLocationCoordinate2D,

        to destination:
            CLLocationCoordinate2D
    ) {

        guard
            isTracking,
            !sessionManager.hasArrived,
            !isRerouting
        else {
            return
        }


        isRerouting =
            true


        rerouteErrorMessage =
            nil


        canRetryReroute =
            false


        /*
         Do not clear the old route.

         It remains visible and active while
         MapKit calculates the replacement route.
         */

        rerouteManager
            .calculateRoute(
                from:
                    start,

                to:
                    destination
            ) {
                [weak self] newRoute in

                guard let self else {
                    return
                }


                DispatchQueue.main.async {

                    self.isRerouting =
                        false


                    /*
                     Ignore a route result that
                     returns after the user has
                     already arrived or tracking
                     has ended.
                     */

                    guard
                        self.isTracking,
                        !self.sessionManager.hasArrived
                    else {
                        return
                    }


                    // MARK: Failure

                    guard let newRoute else {

                        self.rerouteErrorMessage =
                            self
                                .rerouteManager
                                .errorMessage
                            ??
                            "SafeWalk couldn't update your route. Your existing route will remain active."


                        self.canRetryReroute =
                            true


                        /*
                         Restore monitoring against
                         the previous route.
                         */

                        if let existingRoute =
                            self.route {

                            self.journeyMonitor
                                .startMonitoring(
                                    route:
                                        existingRoute,

                                    destination:
                                        destination,

                                    checkInManager:
                                        self
                                            .checkInManager,

                                    journeyID:
                                        self.sessionManager.journeyID
                                )
                        }


                        return
                    }


                    // MARK: Success

                    self.route =
                        newRoute


                    self.rerouteVersion +=
                        1


                    self.rerouteErrorMessage =
                        nil


                    self.canRetryReroute =
                        false


                    self.lastRerouteStart =
                        nil


                    self.lastRerouteDestination =
                        nil


                    self.journeyMonitor
                        .startMonitoring(
                            route:
                                newRoute,

                            destination:
                                destination,

                            checkInManager:
                                self
                                    .checkInManager,

                            journeyID:
                                self.sessionManager.journeyID
                        )

                    self.sessionManager
                        .clearPendingReroute()


                    self.progressManager
                        .startJourney(
                            route:
                                newRoute
                        )


                    if let current =
                        self
                            .locationManager
                            .location {

                        self.journeyMonitor
                            .processLocation(
                                current
                            )


                        if !self.sessionManager.hasArrived {

                            self.progressManager
                                .updateProgress(
                                    userLocation:
                                        current.coordinate,

                                    destination:
                                        destination
                                )
                        }
                    }
                }
            }
    }


    // MARK: - Retry Reroute

    func retryReroute() {

        guard
            isTracking,
            !sessionManager.hasArrived,
            !isRerouting
        else {
            return
        }


        /*
         Prefer the latest location.
         */

        if
            let current =
                locationManager.location,

            let destination =
                destinationCoordinate {

            lastRerouteStart =
                current.coordinate


            lastRerouteDestination =
                destination


            performReroute(
                from:
                    current.coordinate,

                to:
                    destination
            )


            return
        }


        /*
         If GPS is currently unavailable, retry
         the last known reroute request.
         */

        guard
            let start =
                lastRerouteStart,

            let destination =
                lastRerouteDestination
        else {

            rerouteErrorMessage =
                "SafeWalk can't retry the route update because your current location is unavailable."


            canRetryReroute =
                false


            return
        }


        performReroute(
            from:
                start,

            to:
                destination
        )
    }


    // MARK: - Clear Reroute Error

    func clearRerouteError() {

        rerouteErrorMessage =
            nil


        canRetryReroute =
            false
    }


    // MARK: - App Lifecycle

    private func observeAppLifecycle() {

        // Background

        NotificationCenter
            .default
            .publisher(
                for:
                    UIApplication
                        .didEnterBackgroundNotification
            )
            .receive(on: DispatchQueue.main)
            .sink {
                [weak self] _ in

                guard
                    let self,
                    self.isTracking,
                    !self.sessionManager.hasArrived
                else {
                    return
                }


                self.checkInManager
                    .appDidEnterBackground()


                self.periodicCheckInManager
                    .appDidEnterBackground()


                if self
                    .locationManager
                    .authorizationStatus ==
                    .authorizedAlways {

                    self.locationManager
                        .startBackgroundTracking()
                }
            }
            .store(
                in: &cancellables
            )


        // Foreground

        NotificationCenter
            .default
            .publisher(
                for:
                    UIApplication
                        .didBecomeActiveNotification
            )
            .receive(on: DispatchQueue.main)
            .sink {
                [weak self] _ in

                guard
                    let self,
                    self.isTracking,
                    !self.sessionManager.hasArrived
                else {
                    return
                }


                self.checkInManager
                    .appDidBecomeActive()


                self
                    .synchronizeRestoredSafetyState()


                self
                    .startPeriodicCheckIns()


                if self
                    .locationManager
                    .authorizationStatus ==
                    .authorizedAlways {

                    self.locationManager
                        .startBackgroundTracking()
                }
            }
            .store(
                in: &cancellables
            )
    }


    // MARK: - Stop Tracking

    func stopTracking() {

        isTracking =
            false


        isEmergencyEscalationActive =
            false


        sessionManager
            .clearEmergencyEscalation()


        isRerouting =
            false


        clearRerouteError()


        lastRerouteStart =
            nil


        lastRerouteDestination =
            nil


        rerouteManager
            .cancelRouteCalculation()


        journeyMonitor
            .stopMonitoring()


        checkInManager
            .reset()

        NotificationManager.shared
            .cancelPendingMissedCheckInNotification()


        periodicCheckInManager
            .stop()


        progressManager
            .reset()


        locationManager
            .stopUpdatingLocation()


        route =
            nil


        destinationCoordinate =
            nil
    }


    private func scheduleMissedCheckInNotification() {

        guard
            let deadline = checkInManager.checkInDeadline,
            let journeyID = sessionManager.journeyID
        else {
            return
        }

        NotificationManager.shared
            .sendMissedCheckInNotification(
                journeyID: journeyID,
                at: deadline
            )
    }
}
