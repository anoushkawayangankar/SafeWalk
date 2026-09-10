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

    let requiredOffRouteChecks = 3

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

        if pointCount == 1 {
            minimumDistance = userPoint.distance(to: points[0])
        } else if pointCount > 1 {
            for index in 0..<(pointCount - 1) {
                minimumDistance = min(
                    minimumDistance,
                    distance(
                        from: userPoint,
                        toSegmentFrom: points[index],
                        to: points[index + 1]
                    )
                )
            }
        }

        guard minimumDistance.isFinite else {
            reset()
            return
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

    }

    private func distance(
        from point: MKMapPoint,
        toSegmentFrom start: MKMapPoint,
        to end: MKMapPoint
    ) -> CLLocationDistance {

        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let lengthSquared = deltaX * deltaX + deltaY * deltaY

        guard lengthSquared > 0 else {
            return point.distance(to: start)
        }

        let projection = (
            (point.x - start.x) * deltaX +
            (point.y - start.y) * deltaY
        ) / lengthSquared

        let clampedProjection = min(max(projection, 0), 1)
        let closestPoint = MKMapPoint(
            x: start.x + clampedProjection * deltaX,
            y: start.y + clampedProjection * deltaY
        )

        return point.distance(to: closestPoint)
    }

    // MARK: - Reset

    func reset() {

        consecutiveOffRouteChecks = 0

        isOffRoute = false

        distanceFromRoute = 0
    }
}
