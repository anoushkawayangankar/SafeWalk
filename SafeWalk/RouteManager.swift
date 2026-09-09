import Foundation
import MapKit
import CoreLocation
import Combine

final class RouteManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var route: MKRoute?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var canRetry = false


    // MARK: - Active Request

    private var activeDirections: MKDirections?


    // MARK: - Retry State

    private var lastStartCoordinate:
        CLLocationCoordinate2D?

    private var lastDestinationCoordinate:
        CLLocationCoordinate2D?


    // MARK: - Calculate Route

    func calculateRoute(
        from start: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        completion: ((MKRoute?) -> Void)? = nil
    ) {

        // Validate coordinates before asking MapKit.

        guard
            CLLocationCoordinate2DIsValid(start),
            CLLocationCoordinate2DIsValid(destination)
        else {

            setFailure(
                message:
                    "SafeWalk received invalid location information.",
                retryable: false
            )

            completion?(nil)

            return
        }


        // Save for Retry Route.

        lastStartCoordinate =
            start

        lastDestinationCoordinate =
            destination


        // Cancel an older request if one
        // is still running.

        activeDirections?.cancel()

        activeDirections = nil


        isLoading = true
        errorMessage = nil
        canRetry = false


        // MARK: Build MapKit Request

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


        activeDirections =
            directions


        // MARK: Calculate

        directions.calculate {
            [weak self, weak directions]
            response,
            error in

            DispatchQueue.main.async {

                guard let self else {
                    return
                }


                /*
                 Ignore an old response if another
                 route calculation replaced it.
                 */

                guard
                    let directions,
                    self.activeDirections === directions
                else {
                    return
                }


                self.activeDirections =
                    nil

                self.isLoading =
                    false


                // MARK: Error

                if let error {

                    self.handleRouteError(
                        error
                    )

                    completion?(nil)

                    return
                }


                // MARK: No Response

                guard let response else {

                    self.setFailure(
                        message:
                            "SafeWalk couldn't calculate a walking route. Please try again.",
                        retryable:
                            true
                    )

                    completion?(nil)

                    return
                }


                // MARK: No Route

                guard
                    let calculatedRoute =
                        response.routes.first
                else {

                    self.setFailure(
                        message:
                            "No walking route could be found between your location and this destination.",
                        retryable:
                            true
                    )

                    completion?(nil)

                    return
                }


                // MARK: Invalid Route

                guard calculatedRoute.distance > 0
                else {

                    self.setFailure(
                        message:
                            "SafeWalk received an invalid route. Please try again.",
                        retryable:
                            true
                    )

                    completion?(nil)

                    return
                }


                // MARK: Success

                self.route =
                    calculatedRoute

                self.errorMessage =
                    nil

                self.canRetry =
                    false


                completion?(
                    calculatedRoute
                )
            }
        }
    }


    // MARK: - Retry

    func retryLastRoute(
        completion: ((MKRoute?) -> Void)? = nil
    ) {

        guard !isLoading
        else {
            return
        }


        guard
            let start =
                lastStartCoordinate,

            let destination =
                lastDestinationCoordinate
        else {

            setFailure(
                message:
                    "There is no previous route request to retry.",
                retryable:
                    false
            )

            completion?(nil)

            return
        }


        calculateRoute(
            from:
                start,

            to:
                destination,

            completion:
                completion
        )
    }


    // MARK: - Cancel Calculation

    func cancelRouteCalculation() {

        activeDirections?
            .cancel()

        activeDirections =
            nil

        isLoading =
            false
    }


    // MARK: - Clear Error

    func clearError() {

        errorMessage =
            nil

        canRetry =
            false
    }


    // MARK: - Clear Route

    func clearRoute() {

        activeDirections?
            .cancel()

        activeDirections =
            nil


        route =
            nil

        isLoading =
            false

        errorMessage =
            nil

        canRetry =
            false


        lastStartCoordinate =
            nil

        lastDestinationCoordinate =
            nil
    }


    // MARK: - Failure State

    private func setFailure(
        message: String,
        retryable: Bool
    ) {

        isLoading =
            false

        errorMessage =
            message

        canRetry =
            retryable
    }


    // MARK: - Error Handling

    private func handleRouteError(
        _ error: Error
    ) {

        let nsError =
            error as NSError


        // MARK: URL / Internet Errors

        if nsError.domain ==
            NSURLErrorDomain {

            switch nsError.code {

            case NSURLErrorNotConnectedToInternet:

                setFailure(
                    message:
                        "You appear to be offline. Connect to the internet and try calculating the route again.",
                    retryable:
                        true
                )


            case NSURLErrorTimedOut:

                setFailure(
                    message:
                        "The route request timed out. Check your internet connection and try again.",
                    retryable:
                        true
                )


            case NSURLErrorNetworkConnectionLost:

                setFailure(
                    message:
                        "Your internet connection was interrupted while SafeWalk was calculating the route.",
                    retryable:
                        true
                )


            default:

                setFailure(
                    message:
                        "SafeWalk couldn't reach the routing service. Check your connection and try again.",
                    retryable:
                        true
                )
            }


            return
        }


        // MARK: MapKit Errors

        if nsError.domain ==
            MKError.errorDomain {

            let code =
                UInt(nsError.code)


            switch code {

            case MKError.Code
                .directionsNotFound
                .rawValue:

                setFailure(
                    message:
                        "No walking route is available for this destination. Try another destination or starting location.",
                    retryable:
                        true
                )


            case MKError.Code
                .loadingThrottled
                .rawValue:

                setFailure(
                    message:
                        "Too many route requests were made in a short time. Wait a moment and try again.",
                    retryable:
                        true
                )


            case MKError.Code
                .placemarkNotFound
                .rawValue:

                setFailure(
                    message:
                        "SafeWalk couldn't identify one of the locations required for this route.",
                    retryable:
                        true
                )


            case MKError.Code
                .serverFailure
                .rawValue:

                setFailure(
                    message:
                        "Apple's routing service is temporarily unavailable. Please try again shortly.",
                    retryable:
                        true
                )


            default:

                setFailure(
                    message:
                        "SafeWalk couldn't calculate the walking route. Please try again.",
                    retryable:
                        true
                )
            }


            return
        }


        // MARK: Unknown Failure

        setFailure(
            message:
                "SafeWalk couldn't calculate the walking route. Please try again.",
            retryable:
                true
        )
    }
}
