import SwiftUI

@main
struct SafeWalkApp: App {

    @StateObject private var sessionManager:
        JourneySessionManager

    @StateObject private var trackingService:
        JourneyTrackingService


    init() {

        // MARK: - Notifications

        _ = NotificationDelegate.shared

        NotificationManager
            .shared
            .configure()


        // MARK: - Shared Journey State

        let session =
            JourneySessionManager()

        let tracking =
            JourneyTrackingService(
                sessionManager: session
            )


        _sessionManager =
            StateObject(
                wrappedValue: session
            )

        _trackingService =
            StateObject(
                wrappedValue: tracking
            )
    }


    var body: some Scene {

        WindowGroup {

            ContentView()
                .environmentObject(
                    sessionManager
                )
                .environmentObject(
                    trackingService
                )
        }
    }
}
