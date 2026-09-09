import SwiftUI

@main
struct SafeWalkApp: App {

    @StateObject private var sessionManager =
        JourneySessionManager()

    @StateObject private var trackingService =
        JourneyTrackingService()


    init() {

        _ = NotificationDelegate.shared

        NotificationManager
            .shared
            .configure()
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
