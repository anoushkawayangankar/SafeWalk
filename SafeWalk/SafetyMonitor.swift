import Foundation
import CoreLocation
import MapKit
import Combine

final class SafetyMonitor: ObservableObject {

    @Published var isOffRoute = false

    @Published var distanceFromRoute:
        CLLocationDistance = 0

    let deviationThreshold:
        CLLocationDistance = 100

    // Keep 1 while testing.
    // Later change this to 3.
    let requiredOffRouteChecks = 1

    private var consecutiveOffRouteChecks = 0

    // MARK: - Check Route

    func checkRouteDeviation(
        userLocation:
            CLLocationCoordinate2D,
        route: MKRoute
    ) {

        let userPoint =
            MKMapPoint(
                userLocation
            )

        let points =
            route.polyline.points()

        let pointCount =
            route.polyline.pointCount

        var minimumDistance =
            Double.greatestFiniteMagnitude

        for index in 0..<pointCount {

            let routePoint =
                points[index]

            let distance =
                userPoint.distance(
                    to: routePoint
                )

            minimumDistance =
                min(
                    minimumDistance,
                    distance
                )
        }

        // IMPORTANT:
        // synchronous update

        distanceFromRoute =
            minimumDistance

        if minimumDistance >
            deviationThreshold {

            consecutiveOffRouteChecks += 1

        } else {

            consecutiveOffRouteChecks = 0

            isOffRoute = false
        }

        if consecutiveOffRouteChecks >=
            requiredOffRouteChecks {

            isOffRoute = true
        }

        print(
            "Route distance:",
            minimumDistance,
            "Off route:",
            isOffRoute
        )
    }

    // MARK: - Reset

    func reset() {

        consecutiveOffRouteChecks = 0

        isOffRoute = false

        distanceFromRoute = 0
    }
}
