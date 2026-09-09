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


    // MARK: - State

    @Published var route: MKRoute?

    @Published var destinationCoordinate:
        CLLocationCoordinate2D?

    @Published var isTracking =
        false

    @Published var isEmergencyEscalationActive =
        false

    @Published private(set) var isRerouting =
        false

    /*
     Incremented only when an actual
     user-confirmed reroute succeeds.
     */

    @Published private(set) var rerouteVersion =
        0


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
            locationManager.objectWillChange
                .eraseToAnyPublisher(),

            journeyMonitor.objectWillChange
                .eraseToAnyPublisher(),

            checkInManager.objectWillChange
                .eraseToAnyPublisher(),

            progressManager.objectWillChange
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
             During the short period where an
             intentional reroute is being created,
             don't trigger another off-route alert
             against the old route.
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

                self?.confirmSafe()
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
                 If another safety situation
                 currently owns the UI, defer
                 this periodic check.
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


    // MARK: - Start

    func startTracking(
        route: MKRoute,
        destination:
            CLLocationCoordinate2D
    ) {

        checkInManager.reset()

        periodicCheckInManager.stop()

        isEmergencyEscalationActive =
            false

        isRerouting =
            false

        rerouteVersion =
            0

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


    // MARK: - Restore

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
         Capture the reason BEFORE
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
         Periodic safety confirmation does
         NOT require navigation rerouting.
         */

        guard reason == .offRoute else {
            return
        }

        guard
            let current =
                locationManager.location,
            let destination =
                destinationCoordinate
        else {
            return
        }

        isRerouting =
            true

        rerouteManager
            .calculateRoute(
                from:
                    current.coordinate,
                to:
                    destination
            ) { [weak self] newRoute in

                guard let self else {
                    return
                }

                defer {

                    self.isRerouting =
                        false
                }

                guard let newRoute else {
                    return
                }

                self.route =
                    newRoute

                self.rerouteVersion += 1

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


    // MARK: - Stop

    func stopTracking() {

        isTracking = false

        isEmergencyEscalationActive =
            false

        isRerouting =
            false

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

        route = nil

        destinationCoordinate = nil
    }
}
