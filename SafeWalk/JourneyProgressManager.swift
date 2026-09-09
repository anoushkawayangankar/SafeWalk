import Foundation
import CoreLocation
import MapKit
import Combine

class JourneyProgressManager: ObservableObject {

    @Published var distanceRemaining: Double = 0
    @Published var estimatedMinutesRemaining: Int = 0
    @Published var progress: Double = 0

    private var originalDistance: Double = 0

    func startJourney(route: MKRoute) {

        originalDistance = route.distance
        distanceRemaining = route.distance
        estimatedMinutesRemaining =
            Int(route.expectedTravelTime / 60)

        progress = 0
    }

    func updateProgress(
        userLocation: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) {

        let user = CLLocation(
            latitude: userLocation.latitude,
            longitude: userLocation.longitude
        )

        let target = CLLocation(
            latitude: destination.latitude,
            longitude: destination.longitude
        )

        let distance = user.distance(from: target)

        DispatchQueue.main.async {

            self.distanceRemaining = distance

            // Approximate walking speed:
            // 1.4 metres per second

            let walkingSpeed = 1.4

            self.estimatedMinutesRemaining =
                Int((distance / walkingSpeed) / 60)

            if self.originalDistance > 0 {

                let calculatedProgress =
                    1 - (distance / self.originalDistance)

                self.progress = min(
                    max(calculatedProgress, 0),
                    1
                )
            }
        }
    }

    func reset() {

        distanceRemaining = 0
        estimatedMinutesRemaining = 0
        progress = 0
        originalDistance = 0
    }
}
