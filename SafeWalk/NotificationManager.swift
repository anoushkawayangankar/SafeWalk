import Foundation
import UserNotifications
import UIKit
import Combine

final class NotificationManager: ObservableObject {

    // MARK: - Shared Instance

    static let shared =
        NotificationManager()


    // MARK: - Published Permission State

    @Published var authorizationStatus:
        UNAuthorizationStatus = .notDetermined

    @Published var notificationsEnabled =
        false


    // MARK: - Identifiers

    static let checkInCategory =
        "SAFEWALK_CHECK_IN"

    static let safeAction =
        "SAFEWALK_IM_SAFE"

    static let openAction =
        "SAFEWALK_OPEN"


    // MARK: - Init

    private init() {

        refreshPermissionStatus()
    }


    // MARK: - Configure

    func configure() {

        registerCategories()

        refreshPermissionStatus()
    }


    // MARK: - Request Permission

    func requestPermission() {

        UNUserNotificationCenter
            .current()
            .requestAuthorization(
                options: [
                    .alert,
                    .sound,
                    .badge
                ]
            ) { [weak self] granted, error in

                if let error {

                    print(
                        "Notification permission error:",
                        error.localizedDescription
                    )

                    return
                }


                print(
                    "Notifications granted:",
                    granted
                )


                self?
                    .refreshPermissionStatus()
            }
    }


    // MARK: - Refresh Permission Status

    func refreshPermissionStatus() {

        UNUserNotificationCenter
            .current()
            .getNotificationSettings {
                [weak self] settings in

                DispatchQueue.main.async {

                    guard let self else {
                        return
                    }


                    self.authorizationStatus =
                        settings.authorizationStatus


                    switch settings
                        .authorizationStatus {

                    case .authorized,
                         .provisional,
                         .ephemeral:

                        self.notificationsEnabled =
                            true


                    case .denied,
                         .notDetermined:

                        self.notificationsEnabled =
                            false


                    @unknown default:

                        self.notificationsEnabled =
                            false
                    }


                    print(
                        "Notification status:",
                        settings.authorizationStatus.rawValue
                    )
                }
            }
    }


    // MARK: - Open Settings

    func openSettings() {

        guard
            let url = URL(
                string:
                    UIApplication
                        .openSettingsURLString
            )
        else {
            return
        }


        UIApplication
            .shared
            .open(url)
    }


    // MARK: - Register Notification Actions

    private func registerCategories() {

        let safe =
            UNNotificationAction(
                identifier:
                    Self.safeAction,

                title:
                    "I'm Safe",

                options: []
            )


        let open =
            UNNotificationAction(
                identifier:
                    Self.openAction,

                title:
                    "Open SafeWalk",

                options: [
                    .foreground
                ]
            )


        let category =
            UNNotificationCategory(
                identifier:
                    Self.checkInCategory,

                actions: [
                    safe,
                    open
                ],

                intentIdentifiers: [],

                options: []
            )


        UNUserNotificationCenter
            .current()
            .setNotificationCategories(
                [category]
            )
    }


    // MARK: - Off-Route Notification

    func sendOffRouteNotification() {

        let content =
            UNMutableNotificationContent()


        content.title =
            "SafeWalk Route Alert"


        content.body =
            """
            You've moved away from your planned route. \
            Please confirm that you're safe.
            """


        content.sound =
            .default


        content.categoryIdentifier =
            Self.checkInCategory


        send(
            identifier:
                "safewalk-off-route",

            content:
                content
        )
    }


    // MARK: - Periodic Safety Notification

    func sendPeriodicCheckInNotification() {

        let content =
            UNMutableNotificationContent()


        content.title =
            "SafeWalk Safety Check-In"


        content.body =
            """
            Quick safety check. \
            Please confirm that you're okay.
            """


        content.sound =
            .default


        content.categoryIdentifier =
            Self.checkInCategory


        send(
            identifier:
                "safewalk-periodic",

            content:
                content
        )
    }


    // MARK: - Missed Check-In Notification

    func sendMissedCheckInNotification() {

        let content =
            UNMutableNotificationContent()


        content.title =
            "SafeWalk Alert"


        content.body =
            """
            Your safety check-in was missed. \
            Open SafeWalk to review emergency options.
            """


        content.sound =
            .default


        send(
            identifier:
                "safewalk-missed",

            content:
                content
        )
    }


    // MARK: - Send Notification

    private func send(
        identifier: String,
        content:
            UNNotificationContent
    ) {

        /*
         Don't attempt to send a user-facing
         notification if permission is known
         to be denied.
         */

        guard authorizationStatus != .denied
        else {

            print(
                "Notification skipped because permission is denied."
            )

            return
        }


        let request =
            UNNotificationRequest(
                identifier:
                    identifier,

                content:
                    content,

                trigger:
                    nil
            )


        UNUserNotificationCenter
            .current()
            .add(request) { error in

                if let error {

                    print(
                        "Notification error:",
                        error.localizedDescription
                    )

                    return
                }


                print(
                    "Notification sent:",
                    identifier
                )
            }
    }
}
