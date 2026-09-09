import Foundation
import CoreLocation
import MapKit
import Combine
import UIKit

final class JourneyTrackingService:
    ObservableObject {

    // MARK: - Managers

    let locationManager =
        LocationManager()

    let journeyMonitor =
        JourneyMonitor()

    let checkInManager =
        CheckInManager()

    let progressManager =
        JourneyProgressManager()

    let periodicCheckInManager =
        PeriodicCheckInManager()

    private let rerouteManager =
        RouteManager()


    // MARK: - Journey State

    @Published var route: MKRoute?

    @Published var destinationCoordinate:
        CLLocationCoordinate2D?

    @Published var isTracking =
        false

    @Published var isEmergencyEscalationActive =
        false


    // MARK: - Reroute State

    @Published private(set) var isRerouting =
        false

    @Published private(set) var rerouteVersion =
        0

    @Published private(set) var rerouteErrorMessage:
        String?

    @Published private(set) var canRetryReroute =
        false


    // MARK: - Retry State

    private var lastRerouteStart:
        CLLocationCoordinate2D?

    private var lastRerouteDestination:
        CLLocationCoordinate2D?


    // MARK: - Combine

    private var cancellables =
        Set<AnyCancellable>()


    // MARK: - Init

    init() {

        observeManagerChanges()

        connectLocationUpdates()

        observeCheckInState()

        observeArrivalState()

        observeAppLifecycle()

        observeNotificationActions()
    }


    // MARK: - Forward Child Updates

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

            progressManager
                .objectWillChange
                .eraseToAnyPublisher(),

            periodicCheckInManager
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


    // MARK: - GPS

    private func connectLocationUpdates() {

        locationManager.onLocationUpdate = {
            [weak self] location in

            guard let self else {
                return
            }

            guard self.isTracking else {
                return
            }

            guard
                let route = self.route,
                let destination =
                    self.destinationCoordinate
            else {
                return
            }


            /*
             While an intentional reroute is
             being calculated, do not trigger
             another off-route event against
             the previous route.
             */

            if !self.isRerouting {

                if !self
                    .journeyMonitor
                    .isMonitoring {

                    self.journeyMonitor
                        .startMonitoring(
                            route:
                                route,

                            destination:
                                destination,

                            checkInManager:
                                self.checkInManager
                        )
                }


                self.journeyMonitor
                    .processLocation(
                        location
                    )
            }


            self.progressManager
                .updateProgress(
                    userLocation:
                        location.coordinate,

                    destination:
                        destination
                )
        }
    }


    // MARK: - Check-In Expiry

    private func observeCheckInState() {

        checkInManager
            .$didExpire
            .removeDuplicates()
            .sink { [weak self] expired in

                guard let self else {
                    return
                }


                guard self.isTracking else {

                    self
                        .isEmergencyEscalationActive =
                        false

                    return
                }


                self
                    .isEmergencyEscalationActive =
                    expired


                guard expired else {
                    return
                }


                NotificationManager
                    .shared
                    .sendMissedCheckInNotification()
            }
            .store(
                in: &cancellables
            )
    }


    // MARK: - Arrival

    private func observeArrivalState() {

        journeyMonitor
            .$hasArrived
            .removeDuplicates()
            .sink { [weak self] arrived in

                guard let self else {
                    return
                }


                guard
                    self.isTracking,
                    arrived
                else {
                    return
                }


                self.checkInManager
                    .reset()


                self.periodicCheckInManager
                    .stop()


                self
                    .isEmergencyEscalationActive =
                    false


                self.clearRerouteError()
            }
            .store(
                in: &cancellables
            )
    }


    // MARK: - Notification Action

    private func observeNotificationActions() {

        NotificationDelegate
            .shared
            .userConfirmedSafe
            .sink { [weak self] in

                self?
                    .confirmSafe()
            }
            .store(
                in: &cancellables
            )
    }


    // MARK: - Periodic Check-In

    private func startPeriodicCheckIns() {

        periodicCheckInManager
            .start { [weak self] in

                guard let self else {
                    return
                }


                guard self.isTracking else {
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
                 If another safety check is already
                 active, defer this periodic check.
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

                    self
                        .periodicCheckInManager
                        .checkInCompleted()

                    return
                }


                self.checkInManager
                    .startCheckIn(
                        reason:
                            .periodic
                    )


                NotificationManager
                    .shared
                    .sendPeriodicCheckInNotification()
            }
    }


    // MARK: - Lifecycle

    private func observeAppLifecycle() {

        NotificationCenter
            .default
            .publisher(
                for:
                    UIApplication
                        .didEnterBackgroundNotification
            )
            .sink { [weak self] _ in

                guard
                    let self,
                    self.isTracking
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


        NotificationCenter
            .default
            .publisher(
                for:
                    UIApplication
                        .didBecomeActiveNotification
            )
            .sink { [weak self] _ in

                guard
                    let self,
                    self.isTracking
                else {
                    return
                }


                self.checkInManager
                    .appDidBecomeActive()


                self.periodicCheckInManager
                    .appDidBecomeActive()


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


    // MARK: - Prepare Location

    func prepareLocation() {

        locationManager
            .requestLocationPermission()


        locationManager
            .startUpdatingLocation()
    }


    // MARK: - Start Tracking

    func startTracking(
        route: MKRoute,
        destination:
            CLLocationCoordinate2D
    ) {

        checkInManager
            .reset()


        periodicCheckInManager
            .stop()


        isEmergencyEscalationActive =
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


        self.route =
            route


        destinationCoordinate =
            destination


        isTracking =
            true


        progressManager
            .startJourney(
                route:
                    route
            )


        journeyMonitor
            .startMonitoring(
                route:
                    route,

                destination:
                    destination,

                checkInManager:
                    checkInManager
            )


        locationManager
            .startUpdatingLocation()


        startPeriodicCheckIns()


        locationManager
            .requestBackgroundLocationPermission()


        if locationManager
            .authorizationStatus ==
            .authorizedAlways {

            locationManager
                .startBackgroundTracking()
        }


        if let current =
            locationManager.location {

            journeyMonitor
                .processLocation(
                    current
                )


            progressManager
                .updateProgress(
                    userLocation:
                        current.coordinate,

                    destination:
                        destination
                )
        }
    }


    // MARK: - Restore Tracking

    func restoreTracking(
        route: MKRoute,
        destination:
            CLLocationCoordinate2D
    ) {

        self.route =
            route


        destinationCoordinate =
            destination


        isTracking =
            true


        isRerouting =
            false


        clearRerouteError()


        progressManager
            .startJourney(
                route:
                    route
            )


        journeyMonitor
            .startMonitoring(
                route:
                    route,

                destination:
                    destination,

                checkInManager:
                    checkInManager
            )


        prepareLocation()


        startPeriodicCheckIns()


        if locationManager
            .authorizationStatus ==
            .authorizedAlways {

            locationManager
                .startBackgroundTracking()

        } else {

            locationManager
                .requestBackgroundLocationPermission()
        }


        if let current =
            locationManager.location {

            journeyMonitor
                .processLocation(
                    current
                )


            progressManager
                .updateProgress(
                    userLocation:
                        current.coordinate,

                    destination:
                        destination
                )
        }


        checkInManager
            .appDidBecomeActive()


        isEmergencyEscalationActive =
            checkInManager.didExpire
    }


    // MARK: - I'm Safe

    func confirmSafe() {

        guard isTracking else {
            return
        }


        /*
         Capture the reason before
         confirmSafe() clears it.
         */

        let reason =
            checkInManager.reason


        checkInManager
            .confirmSafe()


        isEmergencyEscalationActive =
            false


        periodicCheckInManager
            .checkInCompleted()


        /*
         A periodic safety check does not
         require navigation rerouting.
         */

        guard reason == .offRoute else {
            return
        }


        beginReroute()
    }


    // MARK: - Begin Reroute

    private func beginReroute() {

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

        guard !isRerouting else {
            return
        }


        isRerouting =
            true


        rerouteErrorMessage =
            nil

        canRetryReroute =
            false


        /*
         Do NOT clear self.route here.

         If rerouting fails, the existing route
         remains available for display and
         recovery.
         */

        rerouteManager
            .calculateRoute(
                from:
                    start,

                to:
                    destination
            ) { [weak self] newRoute in

                guard let self else {
                    return
                }


                self.isRerouting =
                    false


                // MARK: Failure

                guard let newRoute else {

                    self.rerouteErrorMessage =
                        self.rerouteManager
                            .errorMessage ??
                        "SafeWalk couldn't update your route. Your existing route will remain active."

                    self.canRetryReroute =
                        true

                    /*
                     Restart monitoring against the
                     existing route if necessary.
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
                                    self.checkInManager
                            )
                    }


                    return
                }


                // MARK: Success

                self.route =
                    newRoute


                self.rerouteVersion += 1


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
                            self.checkInManager
                    )


                self.progressManager
                    .startJourney(
                        route:
                            newRoute
                    )


                if let current =
                    self.locationManager
                        .location {

                    self.journeyMonitor
                        .processLocation(
                            current
                        )


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


    // MARK: - Retry Reroute

    func retryReroute() {

        guard
            isTracking,
            !isRerouting
        else {
            return
        }


        /*
         Prefer the newest GPS position rather
         than blindly using the old failed
         reroute start coordinate.
         */

        if let current =
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


    // MARK: - Stop Tracking

    func stopTracking() {

        isTracking =
            false


        isEmergencyEscalationActive =
            false


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
}
