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


    // MARK: - Journey State

    @State private var journeyStartDate: Date?

    @State private var isShowingArrivalCompletion = false


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
        self.destination = destination
        self.selectedDestination = selectedDestination
    }


    // MARK: - Destination Name

    private var currentDestination: String {

        if
            sessionManager.isJourneyActive,
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

        if sessionManager.isJourneyActive {

            return sessionManager.destinationCoordinate
        }

        if let selectedDestination {

            return selectedDestination
                .location
                .coordinate
        }

        if let selected =
            destinationSearch.selectedDestination {

            return selected
                .location
                .coordinate
        }

        return nil
    }


    // MARK: - Displayed Route

    private var displayedRoute: MKRoute? {

        if sessionManager.isJourneyActive {

            return trackingService.route
                ?? routeManager.route
        }

        return routeManager.route
    }


    // MARK: - Journey Duration

    private var journeyDurationMinutes: Int {

        guard let startDate =
            sessionManager.journeyStartDate
            ?? journeyStartDate
        else {
            return 0
        }

        let duration =
            Date().timeIntervalSince(
                startDate
            )

        return max(
            0,
            Int(duration / 60)
        )
    }


    // MARK: - Completion Distance

    private var completionDistance: Double {

        if sessionManager.originalPlannedDistance > 0 {

            return sessionManager
                .originalPlannedDistance
        }

        return displayedRoute?
            .distance
            ?? 0
    }


    private var isArrivalCompletionVisible: Bool {
        sessionManager.hasArrived || isShowingArrivalCompletion
    }


    // MARK: - Body

    var body: some View {

        ScrollView {

            VStack(
                spacing: 20
            ) {

                headerContent

                if sessionManager.hasArrived {

                    arrivalContent

                } else {

                locationPermissionContent()

                notificationPermissionContent()


                // MARK: Destination Search

                if destinationSearch.isSearching {

                    ProgressView(
                        "Finding destination..."
                    )
                }


                if let error =
                    destinationSearch.errorMessage {

                    searchFailureContent(
                        message: error
                    )
                }


                // MARK: Main Journey Content

                if
                    let latitude =
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


                    MapView(
                        userCoordinate:
                            userCoordinate,

                        destinationCoordinate:
                            destinationCoordinate,

                        route:
                            displayedRoute
                    )
                    .frame(
                        height: 330
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 20
                        )
                    )


                    VStack(
                        spacing: 4
                    ) {

                        Text(
                            "Destination"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )


                        Text(
                            currentDestination
                        )
                        .font(
                            .headline
                        )
                        .multilineTextAlignment(
                            .center
                        )
                    }


                    routeInformation


                    if sessionManager.isJourneyActive {

                        activeJourneyContent

                    } else {

                        inactiveJourneyContent
                    }

                } else {

                    waitingContent
                }


                // MARK: Location Error

                if let error =
                    trackingService
                        .locationManager
                        .locationError {

                    Text(
                        error
                    )
                    .font(
                        .footnote
                    )
                    .foregroundStyle(
                        .red
                    )
                    .multilineTextAlignment(
                        .center
                    )
                }
                }
            }
            .padding()
        }
        .navigationTitle(
            "SafeWalk"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )

        // MARK: On Appear

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
                !sessionManager.isJourneyActive
            else {
                return
            }

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

        // MARK: Selected Destination

        .onReceive(
            destinationSearch
                .$selectedDestination
        ) { selected in

            guard
                !sessionManager.isJourneyActive
            else {
                return
            }

            guard selected != nil else {
                return
            }

            guard routeManager.route == nil else {
                return
            }

            guard
                trackingService
                    .locationManager
                    .location != nil
            else {
                return
            }

            calculateRoute()
        }

        // MARK: GPS Updates

        .onReceive(
            trackingService
                .locationManager
                .$location
        ) { location in

            guard let location else {
                return
            }

            handleLocation(
                location
            )
        }

        // MARK: Route Restoration

        .onReceive(
            routeManager
                .$route
        ) { route in

            guard
                sessionManager.isJourneyActive,
                !sessionManager.hasArrived
            else {
                return
            }

            guard
                !trackingService.isTracking
            else {
                return
            }

            guard
                let route,
                let destination =
                    currentDestinationCoordinate
            else {
                return
            }

            guard
                routeManager.errorMessage == nil
            else {
                return
            }

            trackingService
                .restoreTracking(
                    route: route,
                    destination: destination
                )
        }

        // MARK: Successful Reroute

        .onReceive(
            trackingService
                .$rerouteVersion
                .removeDuplicates()
        ) { version in

            guard version > 0 else {
                return
            }

            guard
                let distance =
                    trackingService
                        .route?
                        .distance
            else {
                return
            }

            sessionManager
                .recordReroute(
                    newPlannedDistance:
                        distance
                )
        }

        // MARK: Arrival

        .onReceive(
            trackingService
                .journeyMonitor
                .$hasArrived
                .removeDuplicates()
        ) { arrived in

            guard arrived else {
                return
            }

            guard sessionManager.isJourneyActive else {
                return
            }

            /*
             Do NOT end the journey immediately.

             Keep the session alive while the
             completion screen is displayed.
             */

            isShowingArrivalCompletion =
                true
        }

        // MARK: Location Authorization

        .onReceive(
            trackingService
                .locationManager
                .$authorizationStatus
                .removeDuplicates()
        ) { status in

            guard
                sessionManager.isJourneyActive,
                !sessionManager.hasArrived,
                trackingService.isTracking
            else {
                return
            }

            if status ==
                .authorizedAlways {

                trackingService
                    .locationManager
                    .startBackgroundTracking()
            }
        }
    }


    // MARK: - Header

    private var headerContent:
        some View {

        VStack(
            spacing: 6
        ) {

            Image(
                systemName:
                    isArrivalCompletionVisible
                    ? "checkmark.circle.fill"
                    : "figure.walk.circle.fill"
            )
            .font(
                .system(
                    size: 52
                )
            )
            .foregroundStyle(
                isArrivalCompletionVisible
                ? .green
                : .blue
            )


            Text(
                isArrivalCompletionVisible
                ? "Journey Complete"
                : (
                    sessionManager.isJourneyActive
                    ? "SafeWalk Active"
                    : "Plan Your SafeWalk"
                )
            )
            .font(
                .title2
            )
            .fontWeight(
                .bold
            )


            Text(
                currentDestination
            )
            .font(
                .headline
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )
        }
    }


    // MARK: - Inactive Journey

    @ViewBuilder
    private var inactiveJourneyContent:
        some View {

        if routeManager.isLoading {

            routeLoadingContent

        } else if let error =
            routeManager.errorMessage {

            routeFailureContent(
                message: error
            )

        } else if displayedRoute != nil {

            startJourneyButton

        } else {

            Button {

                calculateRoute()

            } label: {

                Label(
                    "Calculate Walking Route",
                    systemImage:
                        "arrow.triangle.branch"
                )
                .frame(
                    maxWidth:
                        .infinity
                )
            }
            .buttonStyle(
                .borderedProminent
            )
        }
    }


    // MARK: - Search Failure

    @ViewBuilder
    private func searchFailureContent(
        message: String
    ) -> some View {

        VStack(
            spacing: 10
        ) {

            Image(
                systemName:
                    "magnifyingglass.circle"
            )
            .font(
                .title2
            )


            Text(
                message
            )
            .font(
                .footnote
            )
            .multilineTextAlignment(
                .center
            )


            if destinationSearch.canRetry {

                Button(
                    "Retry Search"
                ) {

                    destinationSearch
                        .retryLastSearch()
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
            .thinMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
    }


    // MARK: - Route Loading

    private var routeLoadingContent:
        some View {

        VStack(
            spacing: 10
        ) {

            ProgressView()


            Text(
                "Calculating your walking route..."
            )
            .font(
                .footnote
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding()
    }


    // MARK: - Route Failure

    @ViewBuilder
    private func routeFailureContent(
        message: String
    ) -> some View {

        VStack(
            spacing: 12
        ) {

            Image(
                systemName:
                    "wifi.exclamationmark"
            )
            .font(
                .title2
            )
            .foregroundStyle(
                .orange
            )


            Text(
                "Route unavailable"
            )
            .font(
                .headline
            )


            Text(
                message
            )
            .font(
                .footnote
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )


            if routeManager.canRetry {

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
            }
        }
        .padding()
        .frame(
            maxWidth: .infinity
        )
        .background(
            .thinMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
    }


    // MARK: - Location Permission

    @ViewBuilder
    private func locationPermissionContent()
        -> some View {

        let manager =
            trackingService.locationManager


        if manager.locationPermissionDenied {

            VStack(
                spacing: 12
            ) {

                Image(
                    systemName:
                        "location.slash.fill"
                )
                .font(
                    .title2
                )
                .foregroundStyle(
                    .orange
                )


                Text(
                    "Location Access Required"
                )
                .font(
                    .headline
                )


                Text(
                    "SafeWalk needs your location to calculate routes, detect off-route movement and monitor your journey."
                )
                .font(
                    .footnote
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
            .frame(
                maxWidth: .infinity
            )
            .background(
                .thinMaterial
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16
                )
            )

        } else if
            manager.authorizationStatus ==
            .notDetermined {

            Button(
                "Allow Location"
            ) {

                manager
                    .requestLocationPermission()
            }
            .buttonStyle(
                .borderedProminent
            )
        }


        if
            sessionManager.isJourneyActive,
            !isShowingArrivalCompletion,
            manager.hasLocationPermission,
            !manager.hasBackgroundPermission {

            VStack(
                spacing: 8
            ) {

                Text(
                    "Background tracking is limited"
                )
                .font(
                    .subheadline
                )
                .fontWeight(
                    .semibold
                )


                Button(
                    "Allow Background Location"
                ) {

                    manager
                        .requestBackgroundLocationPermission()
                }
                .buttonStyle(
                    .bordered
                )
            }
            .padding()
        }


        if
            manager.hasLocationPermission,
            !manager.isPreciseLocationEnabled {

            Text(
                "Precise Location is disabled. Off-route and arrival detection may be less accurate."
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .orange
            )
            .multilineTextAlignment(
                .center
            )
        }
    }


    // MARK: - Notification Permission

    @ViewBuilder
    private func notificationPermissionContent()
        -> some View {

        if notificationManager
            .authorizationStatus ==
            .denied {

            VStack(
                spacing: 10
            ) {

                Text(
                    "Notifications Disabled"
                )
                .font(
                    .headline
                )


                Text(
                    "Enable notifications so SafeWalk can send safety check-ins and missed check-in alerts."
                )
                .font(
                    .footnote
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

                    notificationManager
                        .openSettings()
                }
                .buttonStyle(
                    .bordered
                )
            }
            .padding()

        } else if
            notificationManager
                .authorizationStatus ==
                .notDetermined {

            Button(
                "Enable Notifications"
            ) {

                notificationManager
                    .requestPermission()
            }
            .buttonStyle(
                .bordered
            )
        }
    }


    // MARK: - Route Information

    @ViewBuilder
    private var routeInformation:
        some View {

        if let route =
            displayedRoute {

            HStack(
                spacing: 30
            ) {

                VStack {

                    Text(
                        String(
                            format:
                                "%.2f km",
                            route.distance / 1000
                        )
                    )
                    .font(
                        .headline
                    )


                    Text(
                        "Distance"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                VStack {

                    Text(
                        "\(max(1, Int(route.expectedTravelTime / 60))) min"
                    )
                    .font(
                        .headline
                    )


                    Text(
                        "Estimated"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .padding()
            .frame(
                maxWidth: .infinity
            )
            .background(
                .thinMaterial
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16
                )
            )
        }
    }


    // MARK: - Start Journey

    private var startJourneyButton:
        some View {

        Button {

            startJourney()

        } label: {

            Label(
                "Start SafeWalk",
                systemImage:
                    "figure.walk"
            )
            .frame(
                maxWidth: .infinity
            )
        }
        .buttonStyle(
            .borderedProminent
        )
        .controlSize(
            .large
        )
        .accessibilityHint(
            "Starts location monitoring and safety check-ins for this route"
        )
    }


    // MARK: - Active Journey

    @ViewBuilder
    private var activeJourneyContent:
        some View {

        /*
         Arrival has highest priority so an old
         check-in/emergency UI cannot cover the
         completion screen.
         */

        if
            isShowingArrivalCompletion ||
            sessionManager.hasArrived ||
            trackingService
                .journeyMonitor
                .hasArrived {

            arrivalContent

        } else if trackingService
            .isEmergencyEscalationActive {

            emergencyContent

        } else if trackingService
            .checkInManager
            .isCheckInActive {

            checkInContent

        } else {

            normalJourneyContent
        }
    }


    // MARK: - Normal Journey

    private var normalJourneyContent:
        some View {

        VStack(
            spacing: 16
        ) {

            VStack(
                spacing: 8
            ) {

                HStack {

                    Text(
                        "Journey Progress"
                    )
                    .font(
                        .headline
                    )


                    Spacer()


                    Text(
                        "\(Int(trackingService.progressManager.progress * 100))%"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                ProgressView(
                    value:
                        trackingService
                            .progressManager
                            .progress
                )
            }


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
                .font(
                    .caption
                )
            }


            if trackingService.isRerouting {

                ProgressView(
                    "Updating your route..."
                )
            }


            if let error =
                trackingService
                    .rerouteErrorMessage {

                rerouteFailureContent(
                    message: error
                )
            }


            if sessionManager.rerouteCount > 0 {

                Label(
                    "\(sessionManager.rerouteCount) route update\(sessionManager.rerouteCount == 1 ? "" : "s")",
                    systemImage:
                        "arrow.triangle.2.circlepath"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            VStack(
                spacing: 4
            ) {

                Text(
                    "Next safety check-in"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )


                Text(
                    "\(trackingService.periodicCheckInManager.secondsUntilNextCheckIn) sec"
                )
                .font(
                    .headline
                )
            }


            distanceToDestinationContent

            backgroundTrackingContent

            endJourneyButton
        }
        .padding()
        .frame(
            maxWidth: .infinity
        )
        .background(
            .thinMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }


    // MARK: - Reroute Failure

    @ViewBuilder
    private func rerouteFailureContent(
        message: String
    ) -> some View {

        VStack(
            spacing: 10
        ) {

            Label(
                "Route update failed",
                systemImage:
                    "exclamationmark.triangle"
            )
            .font(
                .headline
            )
            .foregroundStyle(
                .orange
            )


            Text(
                message
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )


            if trackingService.canRetryReroute {

                Button(
                    "Retry Route Update"
                ) {

                    trackingService
                        .retryReroute()
                }
                .buttonStyle(
                    .bordered
                )
                .accessibilityHint(
                    "Attempts to calculate the replacement walking route again"
                )
            }
        }
        .padding()
    }


    // MARK: - Check-In

    private var checkInContent:
        some View {

        VStack(
            spacing: 18
        ) {

            Image(
                systemName:
                    "hand.raised.fill"
            )
            .font(
                .system(
                    size: 44
                )
            )
            .foregroundStyle(
                .orange
            )


            Text(
                "Are you okay?"
            )
            .font(
                .title2
            )
            .fontWeight(
                .bold
            )


            if trackingService
                .checkInManager
                .reason == .offRoute {

                Text(
                    "SafeWalk detected that you've moved away from your planned route."
                )
                .multilineTextAlignment(
                    .center
                )

            } else {

                Text(
                    "This is your scheduled safety check-in."
                )
                .multilineTextAlignment(
                    .center
                )
            }


            Text(
                "\(trackingService.checkInManager.secondsRemaining)"
            )
            .font(
                .system(
                    size: 46,
                    weight: .bold,
                    design: .rounded
                )
            )


            Text(
                "seconds remaining"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            Button {

                trackingService
                    .confirmSafe()

            } label: {

                Label(
                    "I'm Safe",
                    systemImage:
                        "checkmark.shield.fill"
                )
                .frame(
                    maxWidth: .infinity
                )
            }
            .buttonStyle(
                .borderedProminent
            )
            .controlSize(
                .large
            )
            .accessibilityHint(
                "Confirms your safety and continues the journey"
            )
        }
        .padding()
        .frame(
            maxWidth: .infinity
        )
        .background(
            .orange.opacity(0.08)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }


    // MARK: - Emergency

    private var emergencyContent:
        some View {

        VStack(
            spacing: 18
        ) {

            Image(
                systemName:
                    "exclamationmark.triangle.fill"
            )
            .font(
                .system(
                    size: 48
                )
            )
            .foregroundStyle(
                .red
            )


            Text(
                "Check-In Missed"
            )
            .font(
                .title2
            )
            .fontWeight(
                .bold
            )


            Text(
                "You didn't respond to your safety check-in. Confirm you're safe or use the emergency options."
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )


            Button {

                trackingService
                    .confirmSafe()

            } label: {

                Label(
                    "I'm Safe",
                    systemImage:
                        "checkmark.shield.fill"
                )
                .frame(
                    maxWidth: .infinity
                )
            }
            .buttonStyle(
                .borderedProminent
            )


            NavigationLink {

                EmergencyView()

            } label: {

                Label(
                    "Emergency Options",
                    systemImage:
                        "sos.circle.fill"
                )
                .frame(
                    maxWidth: .infinity
                )
            }
            .buttonStyle(
                .bordered
            )
            .tint(
                .red
            )
            .accessibilityHint(
                "Opens contact, calling, messaging and location-sharing options"
            )
        }
        .padding()
        .frame(
            maxWidth: .infinity
        )
        .background(
            .red.opacity(0.08)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }


    // MARK: - Arrival Completion

    private var arrivalContent:
        some View {

        VStack(
            spacing: 18
        ) {

            Image(
                systemName:
                    "checkmark.circle.fill"
            )
            .font(
                .system(
                    size: 56
                )
            )
            .foregroundStyle(
                .green
            )


            Text(
                "You've Arrived"
            )
            .font(
                .title
            )
            .fontWeight(
                .bold
            )


            Text(
                currentDestination
            )
            .font(
                .headline
            )
            .multilineTextAlignment(
                .center
            )


            Text(
                "Your SafeWalk journey has been completed successfully."
            )
            .font(
                .subheadline
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )


            Divider()


            HStack(
                spacing: 30
            ) {

                VStack(
                    spacing: 4
                ) {

                    Text(
                        String(
                            format:
                                "%.2f km",
                            completionDistance / 1000
                        )
                    )
                    .font(
                        .headline
                    )


                    Text(
                        "Distance"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                VStack(
                    spacing: 4
                ) {

                    Text(
                        "\(journeyDurationMinutes) min"
                    )
                    .font(
                        .headline
                    )


                    Text(
                        "Duration"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                VStack(
                    spacing: 4
                ) {

                    Text(
                        "\(sessionManager.rerouteCount)"
                    )
                    .font(
                        .headline
                    )


                    Text(
                        "Reroutes"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }


            Label(
                "Arrived safely",
                systemImage:
                    "checkmark.shield.fill"
            )
            .foregroundStyle(
                .green
            )
            .fontWeight(
                .semibold
            )


            Button {

                completeJourneyOnArrival()

            } label: {

                Label(
                    "Finish Journey",
                    systemImage:
                        "checkmark"
                )
                .frame(
                    maxWidth: .infinity
                )
            }
            .buttonStyle(
                .borderedProminent
            )
            .controlSize(
                .large
            )
            .accessibilityHint(
                "Saves the completed journey once and clears the active session"
            )
        }
        .padding()
        .frame(
            maxWidth: .infinity
        )
        .background(
            .thinMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20
            )
        )
    }


    // MARK: - Distance Remaining

    private var distanceToDestinationContent:
        some View {

        VStack(
            spacing: 5
        ) {

            Text(
                String(
                    format:
                        "%.2f km remaining",
                    trackingService
                        .progressManager
                        .distanceRemaining / 1000
                )
            )
            .font(
                .headline
            )


            Text(
                "\(trackingService.progressManager.estimatedMinutesRemaining) min estimated"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )
        }
    }


    // MARK: - Background Tracking

    @ViewBuilder
    private var backgroundTrackingContent:
        some View {

        if trackingService
            .locationManager
            .isBackgroundTrackingEnabled {

            Label(
                "Background safety tracking enabled",
                systemImage:
                    "location.fill"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .green
            )

        } else {

            Label(
                "Background tracking limited",
                systemImage:
                    "location.slash"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )
        }
    }


    // MARK: - End Journey Button

    private var endJourneyButton:
        some View {

        Button(
            role: .destructive
        ) {

            finishJourney()

        } label: {

            Label(
                "End Journey",
                systemImage:
                    "xmark.circle"
            )
            .frame(
                maxWidth: .infinity
            )
        }
        .buttonStyle(
            .bordered
        )
        .accessibilityHint(
            "Saves this journey as ended before arrival and stops monitoring"
        )
    }


    // MARK: - Waiting

    private var waitingContent:
        some View {

        VStack(
            spacing: 12
        ) {

            ProgressView()


            Text(
                "Waiting for location and destination..."
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )
        }
        .padding()
    }


    // MARK: - Calculate Route

    private func calculateRoute() {

        guard
            let current =
                trackingService
                    .locationManager
                    .location
        else {
            return
        }


        guard
            let destinationCoordinate =
                currentDestinationCoordinate
        else {

            if !destination.isEmpty {

                destinationSearch
                    .search(
                        for: destination
                    )
            }

            return
        }


        routeManager
            .calculateRoute(
                from:
                    current.coordinate,

                to:
                    destinationCoordinate
            )
    }


    // MARK: - Prepare Journey

    private func prepareJourney() {

        if sessionManager.isJourneyActive {

            journeyStartDate =
                sessionManager.journeyStartDate


            /*
             If JourneyMonitor has already
             detected arrival during this view's
             lifetime, preserve completion UI.
             */

            if sessionManager.hasArrived {

                isShowingArrivalCompletion = true
                trackingService.stopTracking()
                return
            }

            if trackingService
                .journeyMonitor
                .hasArrived {

                isShowingArrivalCompletion =
                    true

                return
            }

            trackingService
                .prepareLocation()


            guard
                let current =
                    trackingService
                        .locationManager
                        .location,

                let destinationCoordinate =
                    currentDestinationCoordinate
            else {
                return
            }


            if
                !trackingService.isTracking,
                routeManager.route == nil,
                routeManager.errorMessage == nil {

                routeManager
                    .calculateRoute(
                        from:
                            current.coordinate,

                        to:
                            destinationCoordinate
                    )
            }

            return
        }

        trackingService
            .prepareLocation()


        if selectedDestination != nil {

            calculateRoute()

            return
        }


        if !destination.isEmpty {

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

        if sessionManager.isJourneyActive {

            if sessionManager.hasArrived {
                isShowingArrivalCompletion = true
                return
            }

            /*
             Once arrival has been detected, don't
             reconstruct or modify navigation.
             */

            if isShowingArrivalCompletion {
                return
            }


            guard
                !trackingService.isTracking,
                routeManager.route == nil,
                !routeManager.isLoading,
                routeManager.errorMessage == nil,
                let destinationCoordinate =
                    currentDestinationCoordinate
            else {
                return
            }


            routeManager
                .calculateRoute(
                    from:
                        location.coordinate,

                    to:
                        destinationCoordinate
                )

            return
        }


        /*
         A selected MKMapItem can reach this view
         before Core Location has produced its
         first reading. Start the route as soon as
         that reading arrives.
         */

        if
            currentDestinationCoordinate != nil,
            routeManager.route == nil,
            !routeManager.isLoading,
            routeManager.errorMessage == nil {

            calculateRoute()

            return
        }


        if
            selectedDestination == nil,
            destinationSearch
                .selectedDestination == nil,
            destinationSearch
                .searchResults
                .isEmpty,
            !destination.isEmpty,
            !destinationSearch
                .isSearching {

            destinationSearch
                .search(
                    for: destination
                )
        }
    }


    // MARK: - Start Journey

    private func startJourney() {

        guard
            let route =
                displayedRoute,

            let destinationCoordinate =
                currentDestinationCoordinate
        else {
            return
        }


        journeyStartDate =
            Date()

        isShowingArrivalCompletion =
            false


        /*
         Uses the exact JourneySessionManager API:
         destination + coordinate + distance.
         */

        sessionManager
            .startJourney(
                destination:
                    currentDestination,

                coordinate:
                    destinationCoordinate,

                plannedDistance:
                    route.distance
            )


        /*
         Use the persisted start date as the
         canonical start time.
         */

        journeyStartDate =
            sessionManager.journeyStartDate


        trackingService
            .startTracking(
                route:
                    route,

                destination:
                    destinationCoordinate
            )
    }


    // MARK: - Manual Journey Finish

    private func finishJourney() {

        guard
            sessionManager.isJourneyActive,
            let journeyID = sessionManager.journeyID
        else {
            return
        }


        let completedDestination =
            currentDestination


        let startDate =
            sessionManager.journeyStartDate
            ?? journeyStartDate
            ?? Date()


        let plannedDistance =
            completionDistance


        let saved = historyManager
            .addJourney(
                id:
                    journeyID,

                destination:
                    completedDestination,

                startDate:
                    startDate,

                endDate:
                    Date(),

                plannedDistance:
                    plannedDistance,

                completedSuccessfully:
                    false,

                wentOffRoute:
                    sessionManager.wentOffRoute,

                checkInTriggered:
                    sessionManager.checkInTriggered,

                checkInExpired:
                    sessionManager.checkInExpired
            )

        guard saved else {
            return
        }


        trackingService
            .stopTracking()


        sessionManager
            .endJourney()


        resetLocalJourneyState()
    }


    // MARK: - Complete Journey On Arrival

    private func completeJourneyOnArrival() {

        guard
            sessionManager.isJourneyActive,
            let journeyID = sessionManager.journeyID
        else {
            return
        }


        /*
         Capture everything BEFORE clearing the
         active session.
         */

        let completedDestination =
            currentDestination


        let startDate =
            sessionManager.journeyStartDate
            ?? journeyStartDate
            ?? Date()


        let plannedDistance =
            completionDistance


        let saved = historyManager
            .addJourney(
                id:
                    journeyID,

                destination:
                    completedDestination,

                startDate:
                    startDate,

                endDate:
                    Date(),

                plannedDistance:
                    plannedDistance,

                completedSuccessfully:
                    true,

                wentOffRoute:
                    sessionManager.wentOffRoute,

                checkInTriggered:
                    sessionManager.checkInTriggered,

                checkInExpired:
                    sessionManager.checkInExpired
            )

        guard saved else {
            return
        }


        /*
         Stop location, route monitoring,
         check-ins, periodic timer and rerouting.
         */

        trackingService
            .stopTracking()


        /*
         Clear persisted journey only AFTER the
         successful history record exists.
         */

        sessionManager
            .endJourney()


        resetLocalJourneyState()
    }


    // MARK: - Reset Local State

    private func resetLocalJourneyState() {

        journeyStartDate =
            nil

        isShowingArrivalCompletion =
            false
    }
}


// MARK: - Preview

#Preview {

    let sessionManager =
        JourneySessionManager()

    let trackingService =
        JourneyTrackingService(
            sessionManager:
                sessionManager
        )


    NavigationStack {

        JourneyView(
            destination:
                "Lalbagh"
        )
    }
    .environmentObject(
        sessionManager
    )
    .environmentObject(
        trackingService
    )
}
