import Foundation
import MapKit
import CoreLocation
import Combine

final class RouteManager: ObservableObject {

    @Published var route: MKRoute?

    @Published var isLoading = false

    @Published var errorMessage: String?

    // MARK: - Calculate

    func calculateRoute(
        from start:
            CLLocationCoordinate2D,
        to destination:
            CLLocationCoordinate2D,
        completion:
            ((MKRoute?) -> Void)? = nil
    ) {

        isLoading = true
        errorMessage = nil

        let request =
            MKDirections.Request()

        request.source =
            MKMapItem(
                location:
                    CLLocation(
                        latitude:
                            start.latitude,
                        longitude:
                            start.longitude
                    ),
                address:
                    nil
            )

        request.destination =
            MKMapItem(
                location:
                    CLLocation(
                        latitude:
                            destination.latitude,
                        longitude:
                            destination.longitude
                    ),
                address:
                    nil
            )

        request.transportType =
            .walking

        request.requestsAlternateRoutes =
            false

        let directions =
            MKDirections(
                request:
                    request
            )

        directions.calculate {
            [weak self]
            response,
            error in

            DispatchQueue.main.async {

                guard let self else {
                    return
                }

                self.isLoading = false

                if let error {

                    self.errorMessage =
                        error.localizedDescription

                    completion?(nil)

                    return
                }

                guard
                    let route =
                        response?
                            .routes
                            .first
                else {

                    self.errorMessage =
                        "No walking route found."

                    completion?(nil)

                    return
                }

                self.route = route

                completion?(route)
            }
        }
    }

    // MARK: - Clear

    func clearRoute() {

        route = nil
        isLoading = false
        errorMessage = nil
    }
}
