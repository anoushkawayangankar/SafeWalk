import Foundation
import CoreLocation
import Combine
import UIKit

final class LocationManager:
    NSObject,
    ObservableObject,
    CLLocationManagerDelegate {

    // MARK: - Core Location Manager

    private let manager = CLLocationManager()


    // MARK: - Journey Callback

    var onLocationUpdate: ((CLLocation) -> Void)?


    // MARK: - Published Location State

    @Published var location: CLLocation?

    @Published var latitude: Double?
    @Published var longitude: Double?

    @Published var authorizationStatus:
        CLAuthorizationStatus = .notDetermined

    @Published var locationError: String?

    @Published var isUpdatingLocation = false

    @Published var isBackgroundTrackingEnabled = false

    @Published var isPreciseLocationEnabled = true

    @Published var areLocationServicesEnabled = true

    private var shouldUpdateLocation = false


    // MARK: - Permission Helpers

    var hasLocationPermission: Bool {

        authorizationStatus == .authorizedWhenInUse ||
        authorizationStatus == .authorizedAlways
    }


    var hasBackgroundPermission: Bool {

        authorizationStatus == .authorizedAlways
    }


    var locationPermissionDenied: Bool {

        authorizationStatus == .denied ||
        authorizationStatus == .restricted
    }


    // MARK: - Init

    override init() {

        super.init()

        manager.delegate = self

        manager.desiredAccuracy =
            kCLLocationAccuracyBest

        manager.distanceFilter = 5

        manager.pausesLocationUpdatesAutomatically =
            false

        authorizationStatus =
            manager.authorizationStatus

        areLocationServicesEnabled =
            CLLocationManager.locationServicesEnabled()

        updateAccuracyState()
    }


    // MARK: - Request Initial Permission

    func requestLocationPermission() {

        shouldUpdateLocation = true

        areLocationServicesEnabled =
            CLLocationManager.locationServicesEnabled()

        guard areLocationServicesEnabled else {
            locationError =
                "Location Services are disabled. Enable them in Settings to use SafeWalk."
            return
        }

        let status =
            manager.authorizationStatus

        authorizationStatus =
            status

        switch status {

        case .notDetermined:

            locationError = nil

            manager
                .requestWhenInUseAuthorization()


        case .authorizedWhenInUse,
             .authorizedAlways:

            locationError = nil

            startUpdatingLocation()


        case .denied:

            locationError =
                "Location access is disabled. Open Settings and allow SafeWalk to access your location."


        case .restricted:

            locationError =
                "Location access is restricted on this device."


        @unknown default:

            locationError =
                "SafeWalk could not determine your location permission status."
        }
    }


    // MARK: - Request Background Permission

    func requestBackgroundLocationPermission() {

        let status =
            manager.authorizationStatus

        switch status {

        case .authorizedAlways:

            locationError = nil


        case .authorizedWhenInUse:

            /*
             iOS requires When In Use permission
             before Always permission can be
             requested.
             */

            manager
                .requestAlwaysAuthorization()


        case .notDetermined:

            /*
             Request normal permission first.

             We should NOT immediately request
             Always permission.
             */

            manager
                .requestWhenInUseAuthorization()


        case .denied:

            locationError =
                "Background safety tracking requires location permission. Enable it in Settings."


        case .restricted:

            locationError =
                "Background location access is restricted on this device."


        @unknown default:

            break
        }
    }


    // MARK: - Start Foreground Tracking

    func startUpdatingLocation() {

        shouldUpdateLocation = true

        let status =
            manager.authorizationStatus

        guard
            status == .authorizedWhenInUse ||
            status == .authorizedAlways
        else {

            isUpdatingLocation = false

            return
        }


        locationError = nil

        manager.startUpdatingLocation()

        isUpdatingLocation = true
    }


    // MARK: - Start Background Tracking

    func startBackgroundTracking() {

        shouldUpdateLocation = true

        let status =
            manager.authorizationStatus


        guard status == .authorizedAlways
        else {

            isBackgroundTrackingEnabled = false

            /*
             Don't repeatedly request Always
             permission from here.

             JourneyTrackingService can decide
             when requesting it is appropriate.
             */

            return
        }


        /*
         IMPORTANT:

         Your SafeWalk target must have:

         Signing & Capabilities
         → Background Modes
         → Location updates

         enabled.
         */

        manager.allowsBackgroundLocationUpdates =
            true

        manager.pausesLocationUpdatesAutomatically =
            false

        manager.startUpdatingLocation()


        isUpdatingLocation = true

        isBackgroundTrackingEnabled = true

        locationError = nil
    }


    // MARK: - Stop Tracking

    func stopUpdatingLocation() {

        shouldUpdateLocation = false

        manager.stopUpdatingLocation()

        manager.allowsBackgroundLocationUpdates =
            false


        isUpdatingLocation = false

        isBackgroundTrackingEnabled = false
    }


    // MARK: - Location Updates

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {

        guard
            let newLocation =
                locations.last
        else {
            return
        }


        // Invalid reading

        guard
            newLocation.horizontalAccuracy >= 0
        else {
            return
        }


        /*
         Ignore very inaccurate readings.

         This is important because SafeWalk
         performs off-route detection.

         A bad GPS reading should not trigger
         an emergency check-in.
         */

        guard
            newLocation.horizontalAccuracy <= 100
        else {
            return
        }


        /*
         Ignore very old cached readings.
         */

        let age =
            abs(
                newLocation
                    .timestamp
                    .timeIntervalSinceNow
            )


        guard age < 30
        else {
            return
        }


        DispatchQueue.main.async {

            self.location =
                newLocation


            self.latitude =
                newLocation
                    .coordinate
                    .latitude


            self.longitude =
                newLocation
                    .coordinate
                    .longitude


            self.locationError =
                nil


            /*
             JourneyTrackingService receives the
             exact same location update.

             This is what drives:

             location
                  ↓
             JourneyTrackingService
                  ↓
             JourneyMonitor
                  ↓
             SafetyMonitor
                  ↓
             off-route detection
                  ↓
             CheckInManager
             */

            self.onLocationUpdate?(
                newLocation
            )
        }
    }


    // MARK: - Authorization Changed

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {

        let status =
            manager.authorizationStatus


        DispatchQueue.main.async {

            self.authorizationStatus =
                status

            self.areLocationServicesEnabled =
                CLLocationManager.locationServicesEnabled()

            self.updateAccuracyState()


            switch status {

            case .authorizedAlways:

                self.locationError =
                    nil

                if self.shouldUpdateLocation {
                    self.startUpdatingLocation()
                }


            case .authorizedWhenInUse:

                self.locationError =
                    nil

                if self.shouldUpdateLocation {
                    self.startUpdatingLocation()
                }


            case .denied:

                self.stopUpdatingLocation()

                self.locationError =
                    """
                    Location access is disabled. \
                    Open Settings and allow SafeWalk \
                    to access your location.
                    """


            case .restricted:

                self.stopUpdatingLocation()

                self.locationError =
                    "Location access is restricted on this device."


            case .notDetermined:

                break


            @unknown default:

                self.locationError =
                    "Unknown location authorization state."
            }
        }
    }


    // MARK: - Accuracy Changed

    private func updateAccuracyState() {

        switch manager.accuracyAuthorization {

        case .fullAccuracy:

            isPreciseLocationEnabled =
                true


        case .reducedAccuracy:

            isPreciseLocationEnabled =
                false


        @unknown default:

            isPreciseLocationEnabled =
                false
        }
    }


    // MARK: - Location Failure

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {

        if let locationError =
            error as? CLError {

            switch locationError.code {

            case .locationUnknown:

                /*
                 Usually temporary.

                 CoreLocation automatically
                 continues trying.
                 */

                return


            case .denied:

                DispatchQueue.main.async {

                    self.locationError =
                        """
                        SafeWalk cannot access your location. \
                        Check Location Services and SafeWalk's \
                        permission in Settings.
                        """
                }

                return


            case .network:

                DispatchQueue.main.async {

                    self.locationError =
                        """
                        Location services are temporarily \
                        unavailable because of a network problem.
                        """
                }

                return


            default:

                break
            }
        }


        DispatchQueue.main.async {

            self.locationError =
                "Unable to determine your location: \(error.localizedDescription)"
        }
    }


    // MARK: - Open Settings

    func openSettings() {

        guard
            let settingsURL =
                URL(
                    string:
                        UIApplication
                            .openSettingsURLString
                )
        else {
            return
        }


        guard
            UIApplication
                .shared
                .canOpenURL(
                    settingsURL
                )
        else {
            return
        }


        UIApplication
            .shared
            .open(
                settingsURL
            )
    }
}
