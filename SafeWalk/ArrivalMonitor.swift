import Foundation
import CoreLocation
import Combine

class ArrivalMonitor: ObservableObject {

    @Published var hasArrived = false
    @Published var distanceToDestination: Double = 0

    let arrivalThreshold: Double = 400

    func checkArrival(
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

            self.distanceToDestination = distance

            if distance <= self.arrivalThreshold {
                self.hasArrived = true
            }
        }
    }

    func reset() {
        hasArrived = false
        distanceToDestination = 0
    }
}
