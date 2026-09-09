import SwiftUI
import CoreLocation
import MapKit
import Combine
import UserNotifications

struct JourneyView: View {

    // MARK: - Destination

    let destination: String
    let selectedDestination: MKMapItem?


    // MARK: - Local Managers

    @StateObject private var historyManager =
        JourneyHistoryManager()

    @StateObject private var destinationSearch =
        DestinationSearch()

    @StateObject private var routeManager =
        RouteManager()

    @ObservedObject private var notificationManager =
        NotificationManager.shared


    // MARK: - Journey Statistics

    @State private var journeyStartDate: Date?

    @State private var journeyWentOffRoute = false

    @State private var journeyCheckInTriggered = false

    @State private var journeyCheckInExpired = false


    // MARK: - Shared State

    @EnvironmentObject var sessionManager:
        JourneySessionManager

    @EnvironmentObject var trackingService:
        JourneyTrackingService


    // MARK: - Initializer

    init(
        destination: String,
        selectedDestination: MKMapItem? = nil
    ) {

        self.destination = destination
        self.selectedDestination = selectedDestination
    }


    // MARK: - Destination Name

    private var currentDestination: String {

        if sessionManager.isJourneyActive &&
            !sessionManager.destinationName.isEmpty {

            return sessionManager.destinationName
        }


        if let name = selectedDestination?.name,
           !name.isEmpty {

            return name
        }


        if let name =
            destinationSearch
                .selectedDestination?
                .name,
           !name.isEmpty {

            return name
        }


        return destination
    }


    // MARK: - Destination Coordinate

    private var currentDestinationCoordinate:
        CLLocationCoordinate2D? {

        if let coordinate =
            selectedDestination?
                .placemark
                .coordinate {

            return coordinate
        }


        if let coordinate =
            destinationSearch
                .selectedDestination?
                .placemark
                .coordinate {

            return coordinate
        }


        if sessionManager.isJourneyActive {

            let latitude =
                sessionManager.destinationLatitude

            let longitude =
                sessionManager.destinationLongitude


            if latitude != 0 ||
                longitude != 0 {

                return CLLocationCoordinate2D(
                    latitude: latitude,
                    longitude: longitude
                )
            }
        }


        return nil
    }


    // MARK: - Displayed Route

    private var displayedRoute: MKRoute? {

        if sessionManager.isJourneyActive {

            return trackingService.route ??
                routeManager.route
        }


        return routeManager.route
    }


    // MARK: - Body

    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                // MARK: Header

                Text("Journey")
                    .font(.largeTitle)
                    .bold()


                Text("You are going to:")


                Text(currentDestination)
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)


                Divider()


                // MARK: Permission Hardening

                locationPermissionContent()

                notificationPermissionContent()


                // MARK: Destination Search

                if destinationSearch.isSearching {

                    ProgressView(
                        "Searching destination..."
                    )
                }


                if let searchError =
                    destinationSearch.errorMessage {

                    Text(searchError)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }


                // MARK: Location + Destination Ready

                if let latitude =
                    trackingService
                        .locationManager
                        .latitude,

                   let longitude =
                    trackingService
                        .locationManager
                        .longitude,

                   let destinationCoordinate =
                    currentDestinationCoordinate {

                    let userCoordinate =
                        CLLocationCoordinate2D(
                            latitude: latitude,
                            longitude: longitude
                        )


                    // MARK: Map

                    MapView(
                        userCoordinate:
                            userCoordinate,

                        destinationCoordinate:
                            destinationCoordinate,

                        route:
                            displayedRoute
                    )
                    .frame(height: 350)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 20
                        )
                    )


                    // MARK: Destination

                    VStack(spacing: 4) {

                        Text("Destination")
                            .font(.caption)
                            .foregroundStyle(.secondary)


                        Text(currentDestination)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }


                    // MARK: Route

                    if let route =
                        displayedRoute {

                        routeInformation(
                            route: route
                        )


                        Divider()


                        if sessionManager
                            .isJourneyActive {

                            activeJourneyContent()

                        } else {

                            startJourneyButton(
                                route: route,

                                destinationCoordinate:
                                    destinationCoordinate
                            )
                        }


                    } else if routeManager
                        .isLoading {

                        ProgressView(
                            "Calculating walking route..."
                        )


                    } else {

                        Button(
                            "Calculate Walking Route"
                        ) {

                            routeManager
                                .calculateRoute(
                                    from:
                                        userCoordinate,

                                    to:
                                        destinationCoordinate
                                )
                        }
                        .buttonStyle(
                            .borderedProminent
                        )
                        .disabled(
                            !trackingService
                                .locationManager
                                .hasLocationPermission
                        )
                    }


                    // MARK: Route Error

                    if let error =
                        routeManager.errorMessage {

                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }


                } else {

                    waitingContent()
                }


                // MARK: Generic Location Error

                if let error =
                    trackingService
                        .locationManager
                        .locationError,

                   !trackingService
                        .locationManager
                        .locationPermissionDenied {

                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
        }


        // MARK: Prepare

        .onAppear {

            prepareJourney()

            notificationManager
                .refreshPermissionStatus()
        }


        // MARK: Search Results

        .onReceive(
            destinationSearch
                .$searchResults
        ) { results in

            guard
                selectedDestination == nil,

                destinationSearch
                    .selectedDestination == nil,

                let first = results.first
            else {
                return
            }


            destinationSearch
                .selectDestination(
                    first
                )
        }


        // MARK: Destination Selected

        .onReceive(
            destinationSearch
                .$selectedDestination
                .compactMap { $0 }
        ) { item in

            guard
                !sessionManager.isJourneyActive,

                routeManager.route == nil,

                let location =
                    trackingService
                        .locationManager
                        .location
            else {
                return
            }


            routeManager
                .calculateRoute(
                    from:
                        location.coordinate,

                    to:
                        item
                            .placemark
                            .coordinate
                )
        }


        // MARK: Location Changes

        .onReceive(
            trackingService
                .locationManager
                .$location
                .compactMap { $0 }
        ) { location in

            handleLocation(
                location
            )
        }


        // MARK: Restored Route

        .onReceive(
            routeManager
                .$route
                .compactMap { $0 }
        ) { route in

            guard
                sessionManager.isJourneyActive,

                !trackingService.isTracking,

                let destination =
                    currentDestinationCoordinate
            else {
                return
            }


            trackingService
                .restoreTracking(
                    route: route,
                    destination: destination
                )
        }


        // MARK: Reroute Persistence

        .onChange(
            of:
                trackingService
                    .rerouteVersion
        ) {

            guard
                trackingService
                    .rerouteVersion > 0,

                let route =
                    trackingService.route
            else {
                return
            }


            sessionManager
                .recordReroute(
                    newPlannedDistance:
                        route.distance
                )
        }


        // MARK: Off-Route History

        .onChange(
            of:
                trackingService
                    .journeyMonitor
                    .isOffRoute
        ) {

            if trackingService
                .journeyMonitor
                .isOffRoute {

                journeyWentOffRoute =
                    true
            }
        }


        // MARK: Check-In History

        .onChange(
            of:
                trackingService
                    .checkInManager
                    .isCheckInActive
        ) {

            if trackingService
                .checkInManager
                .isCheckInActive {

                journeyCheckInTriggered =
                    true
            }
        }


        // MARK: Escalation History

        .onChange(
            of:
                trackingService
                    .isEmergencyEscalationActive
        ) {

            if trackingService
                .isEmergencyEscalationActive {

                journeyCheckInExpired =
                    true
            }
        }


        // MARK: Location Permission Change

        .onChange(
            of:
                trackingService
                    .locationManager
                    .authorizationStatus
        ) {

            guard
                sessionManager.isJourneyActive
            else {
                return
            }


            if trackingService
                .locationManager
                .authorizationStatus ==
                .authorizedAlways {

                trackingService
                    .locationManager
                    .startBackgroundTracking()
            }
        }
    }


    // MARK: - Location Permission Content

    @ViewBuilder
    private func locationPermissionContent()
        -> some View {

        let locationManager =
            trackingService.locationManager


        // MARK: Denied

        if locationManager
            .locationPermissionDenied {

            VStack(spacing: 12) {

                Image(
                    systemName:
                        "location.slash.fill"
                )
                .font(.system(size: 42))
                .foregroundStyle(.red)


                Text(
                    "Location Access Required"
                )
                .font(.title2)
                .bold()


                Text(
                    "SafeWalk needs your location to create routes, detect when you leave your planned path, and monitor an active journey."
                )
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)


                Button(
                    "Open Settings"
                ) {

                    locationManager
                        .openSettings()
                }
                .buttonStyle(
                    .borderedProminent
                )
            }
            .padding()
            .frame(
                maxWidth: .infinity
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 16
                )
                .fill(
                    Color.red.opacity(
                        0.08
                    )
                )
            )


        // MARK: Precise Location Off

        } else if
            locationManager
                .hasLocationPermission &&
            !locationManager
                .isPreciseLocationEnabled {

            VStack(spacing: 10) {

                Label(
                    "Precise Location Is Off",
                    systemImage:
                        "location.circle"
                )
                .font(.headline)
                .foregroundStyle(.orange)


                Text(
                    "SafeWalk can still receive your approximate location, but off-route detection may be less accurate."
                )
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)


                Button(
                    "Open Settings"
                ) {

                    locationManager
                        .openSettings()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(
                maxWidth: .infinity
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 16
                )
                .fill(
                    Color.orange.opacity(
                        0.08
                    )
                )
            )


        // MARK: Background Permission

        } else if
            locationManager
                .authorizationStatus ==
                .authorizedWhenInUse {

            VStack(spacing: 10) {

                Label(
                    "Background Safety Limited",
                    systemImage:
                        "location.fill.viewfinder"
                )
                .font(.headline)


                Text(
                    "SafeWalk can track your journey while the app is open. Allow Always Location access for stronger background safety monitoring."
                )
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)


                Button(
                    "Enable Background Safety"
                ) {

                    locationManager
                        .requestBackgroundLocationPermission()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(
                maxWidth: .infinity
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 16
                )
                .fill(
                    Color.secondary.opacity(
                        0.08
                    )
                )
            )
        }
    }


    // MARK: - Notification Permission Content

    @ViewBuilder
    private func notificationPermissionContent()
        -> some View {

        switch notificationManager
            .authorizationStatus {

        // MARK: Not Requested

        case .notDetermined:

            VStack(spacing: 10) {

                Label(
                    "Safety Notifications Recommended",
                    systemImage:
                        "bell.badge.fill"
                )
                .font(.headline)


                Text(
                    "SafeWalk uses notifications for off-route alerts, periodic safety check-ins, and missed check-in warnings when the app is in the background."
                )
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)


                Button(
                    "Enable Notifications"
                ) {

                    notificationManager
                        .requestPermission()
                }
                .buttonStyle(
                    .borderedProminent
                )
            }
            .padding()
            .frame(
                maxWidth: .infinity
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 16
                )
                .fill(
                    Color.blue.opacity(
                        0.08
                    )
                )
            )


        // MARK: Denied

        case .denied:

            VStack(spacing: 10) {

                Label(
                    "Safety Notifications Disabled",
                    systemImage:
                        "bell.slash.fill"
                )
                .font(.headline)
                .foregroundStyle(.red)


                Text(
                    "SafeWalk may not be able to alert you about safety check-ins while the app is in the background."
                )
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)


                Button(
                    "Open Settings"
                ) {

                    notificationManager
                        .openSettings()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(
                maxWidth: .infinity
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 16
                )
                .fill(
                    Color.red.opacity(
                        0.08
                    )
                )
            )


        // MARK: Enabled

        case .authorized,
             .provisional,
             .ephemeral:

            EmptyView()


        @unknown default:

            EmptyView()
        }
    }


    // MARK: - Route Information

    @ViewBuilder
    private func routeInformation(
        route: MKRoute
    ) -> some View {

        VStack(spacing: 8) {

            Text(
                "Walking Distance: \(route.distance / 1000, specifier: "%.2f") km"
            )


            Text(
                "Estimated Time: \(Int(route.expectedTravelTime / 60)) minutes"
            )
        }
        .font(.headline)
    }


    // MARK: - Start Journey

    @ViewBuilder
    private func startJourneyButton(
        route: MKRoute,
        destinationCoordinate:
            CLLocationCoordinate2D
    ) -> some View {

        Button(
            "Start SafeWalk"
        ) {

            startJourney(
                route: route,

                destinationCoordinate:
                    destinationCoordinate
            )
        }
        .buttonStyle(
            .borderedProminent
        )
        .disabled(
            !trackingService
                .locationManager
                .hasLocationPermission
        )
    }


    // MARK: - Active Journey

    @ViewBuilder
    private func activeJourneyContent()
        -> some View {

        Text("Journey Active")
            .font(.headline)


        if trackingService
            .journeyMonitor
            .hasArrived {

            arrivalContent()


        } else if trackingService
            .isEmergencyEscalationActive {

            emergencyContent()


        } else if trackingService
            .checkInManager
            .isCheckInActive {

            checkInContent()


        } else {

            normalJourneyContent()
        }
    }


    // MARK: - Normal Journey

    @ViewBuilder
    private func normalJourneyContent()
        -> some View {

        VStack(spacing: 14) {

            Text("Journey Progress")
                .font(.headline)


            ProgressView(
                value:
                    trackingService
                        .progressManager
                        .progress
            )


            Text(
                "\(Int(trackingService.progressManager.progress * 100))% complete"
            )
            .font(.caption)
            .foregroundStyle(.secondary)


            Text(
                String(
                    format:
                        "%.2f km remaining",

                    trackingService
                        .progressManager
                        .distanceRemaining /
                        1000
                )
            )


            Text(
                "\(trackingService.progressManager.estimatedMinutesRemaining) min remaining"
            )


            // MARK: Route Status

            if trackingService
                .journeyMonitor
                .isOffRoute {

                Label(
                    "You are off route",
                    systemImage:
                        "exclamationmark.triangle.fill"
                )
                .font(.headline)
                .foregroundStyle(.orange)


                Text(
                    "\(Int(trackingService.journeyMonitor.distanceFromRoute)) metres from planned route"
                )
                .font(.caption)

            } else {

                Label(
                    "You are on your planned route",
                    systemImage:
                        "checkmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(.green)
            }


            // MARK: Rerouting

            if trackingService
                .isRerouting {

                ProgressView(
                    "Updating your route..."
                )
            }


            if sessionManager
                .hasBeenRerouted {

                Label(
                    "Route updated \(sessionManager.rerouteCount) time\(sessionManager.rerouteCount == 1 ? "" : "s")",
                    systemImage:
                        "arrow.triangle.branch"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }


            // MARK: Periodic Check-In

            if trackingService
                .periodicCheckInManager
                .isRunning {

                VStack(spacing: 4) {

                    Text(
                        "Next safety check-in"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)


                    Text(
                        "\(trackingService.periodicCheckInManager.secondsUntilNextCheckIn) sec"
                    )
                    .font(.headline)
                }
            }


            distanceToDestinationContent()

            backgroundTrackingContent()

            endJourneyButton()
        }
    }


    // MARK: - Check-In

    @ViewBuilder
    private func checkInContent()
        -> some View {

        VStack(spacing: 16) {

            let reason =
                trackingService
                    .checkInManager
                    .reason


            Image(
                systemName:
                    reason == .offRoute
                    ? "exclamationmark.triangle.fill"
                    : "checkmark.shield.fill"
            )
            .font(.system(size: 50))
            .foregroundStyle(
                reason == .offRoute
                    ? .orange
                    : .blue
            )


            if reason == .offRoute {

                Text("Are you okay?")
                    .font(.title2)
                    .bold()


                Text(
                    "You've moved away from your planned route."
                )
                .multilineTextAlignment(.center)


                if trackingService
                    .journeyMonitor
                    .distanceFromRoute > 0 {

                    Text(
                        "\(Int(trackingService.journeyMonitor.distanceFromRoute)) metres from your planned route"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }


            } else {

                Text("Safety Check-In")
                    .font(.title2)
                    .bold()


                Text(
                    "This is your scheduled SafeWalk safety check-in. Please confirm that you're okay."
                )
                .multilineTextAlignment(.center)
            }


            Text(
                "\(trackingService.checkInManager.secondsRemaining)"
            )
            .font(
                .system(
                    size: 52,
                    weight: .bold,
                    design: .rounded
                )
            )


            Text("seconds remaining")
                .foregroundStyle(.secondary)


            Button("I'm Safe") {

                trackingService
                    .confirmSafe()
            }
            .buttonStyle(
                .borderedProminent
            )


            distanceToDestinationContent()

            backgroundTrackingContent()

            endJourneyButton()
        }
        .padding()
    }


    // MARK: - Emergency Escalation

    @ViewBuilder
    private func emergencyContent()
        -> some View {

        VStack(spacing: 16) {

            Image(
                systemName:
                    "exclamationmark.triangle.fill"
            )
            .font(.system(size: 60))
            .foregroundStyle(.red)


            Text("Check-In Missed")
                .font(.title2)
                .bold()


            if trackingService
                .checkInManager
                .reason == .offRoute {

                Text(
                    "You moved away from your planned route and didn't respond to the safety check-in."
                )
                .multilineTextAlignment(.center)

            } else {

                Text(
                    "You didn't respond to the scheduled SafeWalk safety check-in."
                )
                .multilineTextAlignment(.center)
            }


            Text("Do you need help?")
                .font(.headline)


            Button("I'm Safe") {

                trackingService
                    .confirmSafe()
            }
            .buttonStyle(
                .borderedProminent
            )


            NavigationLink {

                EmergencyView()
                    .environmentObject(
                        trackingService
                    )

            } label: {

                Label(
                    "Emergency Options",
                    systemImage:
                        "cross.case.fill"
                )
            }
            .buttonStyle(.bordered)


            distanceToDestinationContent()

            backgroundTrackingContent()

            endJourneyButton()
        }
        .padding()
    }


    // MARK: - Arrival

    @ViewBuilder
    private func arrivalContent()
        -> some View {

        VStack(spacing: 16) {

            Image(
                systemName:
                    "checkmark.circle.fill"
            )
            .font(.system(size: 60))
            .foregroundStyle(.green)


            Text("You've Arrived")
                .font(.title)
                .bold()


            Text(
                "SafeWalk completed successfully."
            )
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)


            Button(
                "Finish Journey"
            ) {

                finishJourney(
                    completedSuccessfully:
                        true
                )
            }
            .buttonStyle(
                .borderedProminent
            )
        }
        .padding()
    }


    // MARK: - Distance To Destination

    @ViewBuilder
    private func distanceToDestinationContent()
        -> some View {

        if trackingService
            .journeyMonitor
            .distanceToDestination > 0 {

            Text(
                "Distance to destination: \(Int(trackingService.journeyMonitor.distanceToDestination)) m"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }


    // MARK: - Background Tracking

    @ViewBuilder
    private func backgroundTrackingContent()
        -> some View {

        if trackingService
            .locationManager
            .isBackgroundTrackingEnabled {

            Label(
                "Background safety tracking active",
                systemImage:
                    "location.fill"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }


    // MARK: - End Journey

    @ViewBuilder
    private func endJourneyButton()
        -> some View {

        Button(
            "End Journey",
            role: .destructive
        ) {

            finishJourney(
                completedSuccessfully:
                    false
            )
        }
        .buttonStyle(.bordered)
    }


    // MARK: - Waiting

    @ViewBuilder
    private func waitingContent()
        -> some View {

        if trackingService
            .locationManager
            .locationPermissionDenied {

            EmptyView()


        } else if trackingService
            .locationManager
            .authorizationStatus ==
                .notDetermined {

            VStack(spacing: 10) {

                ProgressView()


                Text(
                    "Waiting for location permission..."
                )
                .foregroundStyle(.secondary)
            }


        } else {

            VStack(spacing: 10) {

                ProgressView()


                Text(
                    "Getting your current location..."
                )
                .foregroundStyle(.secondary)
            }
        }
    }


    // MARK: - Prepare Journey

    private func prepareJourney() {

        trackingService
            .prepareLocation()


        if sessionManager
            .isJourneyActive {

            journeyStartDate =
                sessionManager
                    .journeyStartDate

            return
        }


        if let selectedDestination {

            destinationSearch
                .selectDestination(
                    selectedDestination
                )

        } else {

            destinationSearch
                .search(
                    for: destination
                )
        }
    }


    // MARK: - Handle Location

    private func handleLocation(
        _ location: CLLocation
    ) {

        guard
            let destination =
                currentDestinationCoordinate
        else {
            return
        }


        // MARK: Restored Journey

        if sessionManager
            .isJourneyActive {

            if routeManager.route == nil &&
                !routeManager.isLoading &&
                !trackingService.isTracking {

                routeManager
                    .calculateRoute(
                        from:
                            location.coordinate,

                        to:
                            destination
                    )
            }


            return
        }


        // MARK: New Journey

        if routeManager.route == nil &&
            !routeManager.isLoading {

            routeManager
                .calculateRoute(
                    from:
                        location.coordinate,

                    to:
                        destination
                )
        }
    }


    // MARK: - Start Journey

    private func startJourney(
        route: MKRoute,
        destinationCoordinate:
            CLLocationCoordinate2D
    ) {

        journeyStartDate =
            Date()

        journeyWentOffRoute =
            false

        journeyCheckInTriggered =
            false

        journeyCheckInExpired =
            false


        sessionManager
            .startJourney(
                destination:
                    currentDestination,

                coordinate:
                    destinationCoordinate,

                plannedDistance:
                    route.distance
            )


        trackingService
            .startTracking(
                route: route,

                destination:
                    destinationCoordinate
            )
    }


    // MARK: - Finish Journey

    private func finishJourney(
        completedSuccessfully: Bool
    ) {

        let plannedDistance =
            sessionManager
                .originalPlannedDistance > 0

            ? sessionManager
                .originalPlannedDistance

            : displayedRoute?
                .distance ?? 0


        let finalWentOffRoute =
            journeyWentOffRoute ||

            trackingService
                .journeyMonitor
                .isOffRoute


        let finalCheckInTriggered =
            journeyCheckInTriggered ||

            trackingService
                .checkInManager
                .isCheckInActive ||

            trackingService
                .isEmergencyEscalationActive


        let finalCheckInExpired =
            journeyCheckInExpired ||

            trackingService
                .isEmergencyEscalationActive


        historyManager
            .addJourney(
                destination:
                    currentDestination,

                startDate:
                    journeyStartDate ??
                    sessionManager
                        .journeyStartDate ??
                    Date(),

                endDate:
                    Date(),

                plannedDistance:
                    plannedDistance,

                completedSuccessfully:
                    completedSuccessfully,

                wentOffRoute:
                    finalWentOffRoute,

                checkInTriggered:
                    finalCheckInTriggered,

                checkInExpired:
                    finalCheckInExpired
            )


        trackingService
            .stopTracking()


        sessionManager
            .endJourney()


        destinationSearch
            .clearSelection()


        journeyStartDate =
            nil

        journeyWentOffRoute =
            false

        journeyCheckInTriggered =
            false

        journeyCheckInExpired =
            false
    }
}


// MARK: - Preview

#Preview {

    NavigationStack {

        JourneyView(
            destination:
                "Lalbagh"
        )
    }
    .environmentObject(
        JourneySessionManager()
    )
    .environmentObject(
        JourneyTrackingService()
    )
}
