import SwiftUI
import CoreLocation
import MapKit
import Combine
import UserNotifications

struct JourneyView: View {

    // MARK: - Destination

    let destination: String
    let selectedDestination: MKMapItem?


    // MARK: - Managers

    @StateObject private var historyManager =
        JourneyHistoryManager()

    @StateObject private var destinationSearch =
        DestinationSearch()

    @StateObject private var routeManager =
        RouteManager()

    @ObservedObject private var notificationManager =
        NotificationManager.shared


    // MARK: - Journey History State

    @State private var journeyStartDate: Date?

    @State private var journeyWentOffRoute =
        false

    @State private var journeyCheckInTriggered =
        false

    @State private var journeyCheckInExpired =
        false


    // MARK: - Environment

    @EnvironmentObject var sessionManager:
        JourneySessionManager

    @EnvironmentObject var trackingService:
        JourneyTrackingService


    // MARK: - Init

    init(
        destination: String,
        selectedDestination: MKMapItem? = nil
    ) {

        self.destination =
            destination

        self.selectedDestination =
            selectedDestination
    }


    // MARK: - Current Destination Name

    private var currentDestination: String {

        if sessionManager.isJourneyActive &&
            !sessionManager.destinationName.isEmpty {

            return sessionManager.destinationName
        }


        if let name =
            selectedDestination?.name,
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

        if let selectedDestination {

            return selectedDestination
                .location
                .coordinate
        }


        if let selected =
            destinationSearch
                .selectedDestination {

            return selected
                .location
                .coordinate
        }


        if sessionManager.isJourneyActive {

            let latitude =
                sessionManager
                    .destinationLatitude

            let longitude =
                sessionManager
                    .destinationLongitude


            if latitude != 0 ||
                longitude != 0 {

                return CLLocationCoordinate2D(
                    latitude:
                        latitude,

                    longitude:
                        longitude
                )
            }
        }


        return nil
    }


    // MARK: - Display Route

    private var displayedRoute:
        MKRoute? {

        if sessionManager
            .isJourneyActive {

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


                Text(
                    "You are going to:"
                )


                Text(
                    currentDestination
                )
                .font(.title2)
                .bold()
                .multilineTextAlignment(
                    .center
                )


                Divider()


                // MARK: Permissions

                locationPermissionContent()

                notificationPermissionContent()


                // MARK: Search

                if destinationSearch
                    .isSearching {

                    ProgressView(
                        "Searching destination..."
                    )
                }


                if let error =
                    destinationSearch
                        .errorMessage {

                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .multilineTextAlignment(
                            .center
                        )
                }


                // MARK: Location Ready

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
                            latitude:
                                latitude,

                            longitude:
                                longitude
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


                    // MARK: Destination Name

                    VStack(spacing: 4) {

                        Text("Destination")
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )


                        Text(
                            currentDestination
                        )
                        .font(.headline)
                        .multilineTextAlignment(
                            .center
                        )
                    }


                    // MARK: Route State

                    if let route =
                        displayedRoute {

                        routeInformation(
                            route:
                                route
                        )


                        Divider()


                        if sessionManager
                            .isJourneyActive {

                            activeJourneyContent()

                        } else {

                            startJourneyButton(
                                route:
                                    route,

                                destinationCoordinate:
                                    destinationCoordinate
                            )
                        }


                    } else if routeManager
                        .isLoading {

                        routeLoadingContent()


                    } else if routeManager
                        .errorMessage != nil {

                        routeFailureContent(
                            currentUserCoordinate:
                                userCoordinate,

                            destinationCoordinate:
                                destinationCoordinate
                        )


                    } else {

                        Button(
                            "Calculate Walking Route"
                        ) {

                            calculateRoute(
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


                } else {

                    waitingContent()
                }


                // MARK: Location Error

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
                        .multilineTextAlignment(
                            .center
                        )
                        .padding(.horizontal)
                }
            }
            .padding()
        }


        // MARK: Appeared

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

                let first =
                    results.first
            else {
                return
            }


            destinationSearch
                .selectDestination(
                    first
                )
        }


        // MARK: Selected Destination

        .onReceive(
            destinationSearch
                .$selectedDestination
                .compactMap { $0 }
        ) { item in

            guard
                !sessionManager
                    .isJourneyActive,

                routeManager.route ==
                    nil,

                let location =
                    trackingService
                        .locationManager
                        .location
            else {
                return
            }


            calculateRoute(
                from:
                    location.coordinate,

                to:
                    item
                        .location
                        .coordinate
            )
        }


        // MARK: GPS Changes

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


        // MARK: Restore Tracking

        .onReceive(
            routeManager
                .$route
                .compactMap { $0 }
        ) { route in

            guard
                sessionManager
                    .isJourneyActive,

                !trackingService
                    .isTracking,

                let destination =
                    currentDestinationCoordinate
            else {
                return
            }


            trackingService
                .restoreTracking(
                    route:
                        route,

                    destination:
                        destination
                )
        }


        // MARK: Rerouting

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


        // MARK: Off Route History

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


        // MARK: Background Permission

        .onChange(
            of:
                trackingService
                    .locationManager
                    .authorizationStatus
        ) {

            guard
                sessionManager
                    .isJourneyActive
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


    // MARK: - Route Loading

    @ViewBuilder
    private func routeLoadingContent()
        -> some View {

        VStack(spacing: 12) {

            ProgressView()


            Text(
                "Calculating Walking Route"
            )
            .font(.headline)


            Text(
                "SafeWalk is finding the safest available walking route to your destination."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(
                .center
            )
        }
        .padding()
    }


    // MARK: - Route Failure

    @ViewBuilder
    private func routeFailureContent(
        currentUserCoordinate:
            CLLocationCoordinate2D,

        destinationCoordinate:
            CLLocationCoordinate2D
    ) -> some View {

        VStack(spacing: 12) {

            Image(
                systemName:
                    "exclamationmark.triangle.fill"
            )
            .font(.system(size: 38))
            .foregroundStyle(.orange)


            Text(
                "Unable to Calculate Route"
            )
            .font(.headline)


            if let error =
                routeManager
                    .errorMessage {

                Text(error)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    .multilineTextAlignment(
                        .center
                    )
            }


            if routeManager
                .canRetry {

                Button {

                    routeManager
                        .retryLastRoute()

                } label: {

                    Label(
                        "Retry Route",
                        systemImage:
                            "arrow.clockwise"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )

            } else {

                Button(
                    "Try Again"
                ) {

                    calculateRoute(
                        from:
                            currentUserCoordinate,

                        to:
                            destinationCoordinate
                    )
                }
                .buttonStyle(
                    .bordered
                )
            }
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
                Color.orange
                    .opacity(0.08)
            )
        )
    }


    // MARK: - Location Permission

    @ViewBuilder
    private func locationPermissionContent()
        -> some View {

        let manager =
            trackingService
                .locationManager


        if manager
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
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )


                Button(
                    "Open Settings"
                ) {

                    manager
                        .openSettings()
                }
                .buttonStyle(
                    .borderedProminent
                )
            }
            .padding()


        } else if
            manager
                .hasLocationPermission &&
            !manager
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
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )


                Button(
                    "Open Settings"
                ) {

                    manager
                        .openSettings()
                }
                .buttonStyle(.bordered)
            }
            .padding()


        } else if
            manager
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
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )


                Button(
                    "Enable Background Safety"
                ) {

                    manager
                        .requestBackgroundLocationPermission()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }


    // MARK: - Notification Permission

    @ViewBuilder
    private func notificationPermissionContent()
        -> some View {

        switch notificationManager
            .authorizationStatus {

        case .notDetermined:

            VStack(spacing: 10) {

                Label(
                    "Safety Notifications Recommended",
                    systemImage:
                        "bell.badge.fill"
                )
                .font(.headline)


                Text(
                    "SafeWalk uses notifications for off-route alerts, periodic safety check-ins, and missed check-in warnings."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )


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
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )


                Button(
                    "Open Settings"
                ) {

                    notificationManager
                        .openSettings()
                }
                .buttonStyle(.bordered)
            }
            .padding()


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
                route:
                    route,

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

            Text(
                "Journey Progress"
            )
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
            .foregroundStyle(
                .secondary
            )


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


            if trackingService
                .journeyMonitor
                .isOffRoute {

                Label(
                    "You are off route",
                    systemImage:
                        "exclamationmark.triangle.fill"
                )
                .foregroundStyle(
                    .orange
                )


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
                .foregroundStyle(
                    .green
                )
            }


            if trackingService
                .isRerouting {

                ProgressView(
                    "Updating your route..."
                )
            }
            rerouteFailureContent()


            if sessionManager
                .hasBeenRerouted {

                Label(
                    "Route updated \(sessionManager.rerouteCount) time\(sessionManager.rerouteCount == 1 ? "" : "s")",
                    systemImage:
                        "arrow.triangle.branch"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }


            if trackingService
                .periodicCheckInManager
                .isRunning {

                VStack(spacing: 4) {

                    Text(
                        "Next safety check-in"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )


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
    
    // MARK: - Reroute Failure

    @ViewBuilder
    private func rerouteFailureContent() -> some View {

        if let error =
            trackingService
                .rerouteErrorMessage {

            VStack(spacing: 12) {

                Image(
                    systemName:
                        "arrow.triangle.2.circlepath.circle.fill"
                )
                .font(.system(size: 36))
                .foregroundStyle(.orange)


                Text(
                    "Unable to Update Route"
                )
                .font(.headline)


                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)


                Text(
                    "Your previous route is still available and your SafeWalk journey remains active."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)


                if trackingService
                    .canRetryReroute {

                    Button {

                        trackingService
                            .retryReroute()

                    } label: {

                        Label(
                            "Retry Reroute",
                            systemImage:
                                "arrow.clockwise"
                        )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .disabled(
                        trackingService
                            .isRerouting
                    )
                }


                Button(
                    "Dismiss"
                ) {

                    trackingService
                        .clearRerouteError()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(
                maxWidth:
                    .infinity
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 16
                )
                .fill(
                    Color.orange
                        .opacity(0.08)
                )
            )
        }
    }


    // MARK: - Check In

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

            } else {

                Text(
                    "Safety Check-In"
                )
                .font(.title2)
                .bold()


                Text(
                    "This is your scheduled SafeWalk safety check-in."
                )
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


            Text(
                "seconds remaining"
            )
            .foregroundStyle(
                .secondary
            )


            Button(
                "I'm Safe"
            ) {

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
    }


    // MARK: - Emergency

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


            Text(
                "Check-In Missed"
            )
            .font(.title2)
            .bold()


            Text(
                "You didn't respond to the SafeWalk safety check-in."
            )
            .multilineTextAlignment(
                .center
            )


            Button(
                "I'm Safe"
            ) {

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


            endJourneyButton()
        }
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
            .foregroundStyle(
                .green
            )


            Text("You've Arrived")
                .font(.title)
                .bold()


            Text(
                "SafeWalk completed successfully."
            )
            .foregroundStyle(
                .secondary
            )


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
    }


    // MARK: - Distance

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
            .foregroundStyle(
                .secondary
            )
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
            .foregroundStyle(
                .secondary
            )
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

        } else {

            VStack(spacing: 10) {

                ProgressView()


                Text(
                    "Getting your current location..."
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }


    // MARK: - Calculate Route

    private func calculateRoute(
        from start:
            CLLocationCoordinate2D,

        to destination:
            CLLocationCoordinate2D
    ) {

        routeManager
            .calculateRoute(
                from:
                    start,

                to:
                    destination
            )
    }


    // MARK: - Prepare

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
                    for:
                        destination
                )
        }
    }


    // MARK: - Handle GPS Location

    private func handleLocation(
        _ location: CLLocation
    ) {

        guard
            let destination =
                currentDestinationCoordinate
        else {
            return
        }


        if sessionManager
            .isJourneyActive {

            if routeManager.route == nil &&
                !routeManager.isLoading &&
                !trackingService.isTracking {

                calculateRoute(
                    from:
                        location.coordinate,

                    to:
                        destination
                )
            }


            return
        }


        /*
         Do NOT continually retry automatically
         after a route failure.

         The user should explicitly press
         Retry Route.
         */

        if routeManager.route == nil &&
            !routeManager.isLoading &&
            routeManager.errorMessage == nil {

            calculateRoute(
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
                route:
                    route,

                destination:
                    destinationCoordinate
            )
    }


    // MARK: - Finish Journey

    private func finishJourney(
        completedSuccessfully:
            Bool
    ) {

        let plannedDistance =
            sessionManager
                .originalPlannedDistance > 0

            ? sessionManager
                .originalPlannedDistance

            : displayedRoute?
                .distance ?? 0


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
                    journeyWentOffRoute ||
                    trackingService
                        .journeyMonitor
                        .isOffRoute,

                checkInTriggered:
                    journeyCheckInTriggered ||
                    trackingService
                        .checkInManager
                        .isCheckInActive ||
                    trackingService
                        .isEmergencyEscalationActive,

                checkInExpired:
                    journeyCheckInExpired ||
                    trackingService
                        .isEmergencyEscalationActive
            )


        trackingService
            .stopTracking()


        sessionManager
            .endJourney()


        destinationSearch
            .clearSelection()


        routeManager
            .clearRoute()


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
