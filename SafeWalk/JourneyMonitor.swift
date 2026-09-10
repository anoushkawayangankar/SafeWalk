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

    private var journeyID: UUID?

    // MARK: - Start

    func startMonitoring(
        route: MKRoute,
        destination:
            CLLocationCoordinate2D,
        checkInManager:
            CheckInManager,
        journeyID: UUID? = nil
    ) {

        self.route = route

        self.destinationCoordinate =
            destination

        self.checkInManager =
            checkInManager

        self.journeyID =
            journeyID

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

        guard let route else {
            return
        }

        let coordinate =
            location.coordinate

        // MARK: Arrival

        processArrival(location)

        // MARK: Arrival wins

        if hasArrived {

            return
        }

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
            .sendOffRouteNotification(
                journeyID: journeyID
            )
    }

    // MARK: - Arrival Only

    func processArrival(
        _ location: CLLocation
    ) {

        guard
            isMonitoring,
            let destinationCoordinate
        else {
            return
        }

        arrivalMonitor
            .checkArrival(
                userLocation:
                    location,
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
    }

    // MARK: - Stop

    func stopMonitoring() {

        isMonitoring = false

        route = nil
        destinationCoordinate = nil
        checkInManager = nil
        journeyID = nil

        safetyMonitor.reset()
        arrivalMonitor.reset()

        isOffRoute = false
        distanceFromRoute = 0

        hasArrived = false
        distanceToDestination = 0
    }
}
