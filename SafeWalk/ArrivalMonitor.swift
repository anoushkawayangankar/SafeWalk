import Foundation
import CoreLocation
import Combine

final class ArrivalMonitor: ObservableObject {

    // MARK: - Published State

    @Published private(set) var hasArrived = false

    @Published private(set) var distanceToDestination:
        CLLocationDistance = 0


    // MARK: - Configuration

    /*
     50 metres is a more appropriate default
     arrival radius for a walking journey.

     GPS accuracy is also considered below so
     SafeWalk does not require impossible
     precision.
     */

    private let arrivalThreshold:
        CLLocationDistance = 50


    // MARK: - State

    /*
     Once arrival has been detected, subsequent
     GPS updates must not repeatedly trigger
     arrival.
     */

    private var arrivalConfirmed = false


    // MARK: - Check Arrival

    func checkArrival(
        userLocation: CLLocation,
        destination: CLLocationCoordinate2D
    ) {

        guard !arrivalConfirmed else {
            return
        }


        guard
            CLLocationCoordinate2DIsValid(
                userLocation.coordinate
            ),
            CLLocationCoordinate2DIsValid(
                destination
            )
        else {
            return
        }


        let target =
            CLLocation(
                latitude:
                    destination.latitude,

                longitude:
                    destination.longitude
            )


        let distance =
            userLocation.distance(
                from:
                    target
            )

        distanceToDestination = distance

        guard
            userLocation.horizontalAccuracy >= 0,
            userLocation.horizontalAccuracy <= arrivalThreshold,
            distance <= arrivalThreshold
        else {
            return
        }

        arrivalConfirmed = true
        hasArrived = true
    }


    // MARK: - Reset

    func reset() {

        arrivalConfirmed =
            false


        hasArrived =
            false


        distanceToDestination =
            0
    }
}
