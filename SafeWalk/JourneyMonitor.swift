import Foundation
import CoreLocation
import MapKit
import Combine

final class JourneyMonitor: ObservableObject {

    @Published var isMonitoring = false

    @Published var isOffRoute = false

    @Published var distanceFromRoute:
        CLLocationDistance = 0

    @Published var hasArrived = false

    @Published var distanceToDestination:
        CLLocationDistance = 0

    private var route: MKRoute?

    private var destinationCoordinate:
        CLLocationCoordinate2D?

    private let safetyMonitor =
        SafetyMonitor()

    private let arrivalMonitor =
        ArrivalMonitor()

    private var checkInManager:
        CheckInManager?

    // MARK: - Start

    func startMonitoring(
        route: MKRoute,
        destination:
            CLLocationCoordinate2D,
        checkInManager:
            CheckInManager
    ) {

        self.route = route

        self.destinationCoordinate =
            destination

        self.checkInManager =
            checkInManager

        isMonitoring = true

        safetyMonitor.reset()
        arrivalMonitor.reset()

        isOffRoute = false
        distanceFromRoute = 0

        hasArrived = false
        distanceToDestination = 0
    }

    // MARK: - GPS

    func processLocation(
        _ location: CLLocation
    ) {

        guard isMonitoring else {
            return
        }

        guard
            let route,
            let destinationCoordinate
        else {
            return
        }

        let coordinate =
            location.coordinate

        // MARK: Route deviation

        safetyMonitor
            .checkRouteDeviation(
                userLocation:
                    coordinate,
                route:
                    route
            )

        isOffRoute =
            safetyMonitor.isOffRoute

        distanceFromRoute =
            safetyMonitor.distanceFromRoute

        // MARK: Arrival

        arrivalMonitor
            .checkArrival(
                userLocation:
                    coordinate,
                destination:
                    destinationCoordinate
            )

        hasArrived =
            arrivalMonitor.hasArrived

        distanceToDestination =
            arrivalMonitor
                .distanceToDestination

        // MARK: Arrival wins

        if hasArrived {

            checkInManager?
                .reset()

            safetyMonitor.reset()

            isOffRoute = false
            distanceFromRoute = 0

            return
        }

        // MARK: Off Route

        guard isOffRoute else {
            return
        }

        guard let checkInManager else {
            return
        }

        guard
            !checkInManager
                .isCheckInActive
        else {
            return
        }

        guard
            !checkInManager
                .didExpire
        else {
            return
        }

        checkInManager
            .startCheckIn(
                reason: .offRoute
            )

        NotificationManager
            .shared
            .sendOffRouteNotification()
    }

    // MARK: - Stop

    func stopMonitoring() {

        isMonitoring = false

        route = nil
        destinationCoordinate = nil
        checkInManager = nil

        safetyMonitor.reset()
        arrivalMonitor.reset()

        isOffRoute = false
        distanceFromRoute = 0

        hasArrived = false
        distanceToDestination = 0
    }
}
