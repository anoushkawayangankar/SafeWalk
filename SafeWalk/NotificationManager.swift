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
            ) { [weak self] _, error in

                if error != nil {
                    return
                }


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

    func sendOffRouteNotification(
        journeyID: UUID?
    ) {

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

        addJourneyID(journeyID, to: content)


        send(
            identifier:
                "safewalk-off-route",

            content:
                content
        )
    }


    // MARK: - Periodic Safety Notification

    func sendPeriodicCheckInNotification(
        journeyID: UUID?
    ) {

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

        addJourneyID(journeyID, to: content)


        send(
            identifier:
                "safewalk-periodic",

            content:
                content
        )
    }


    // MARK: - Missed Check-In Notification

    func sendMissedCheckInNotification(
        journeyID: UUID?,
        at deadline: Date? = nil
    ) {

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

        content.categoryIdentifier =
            Self.checkInCategory

        addJourneyID(journeyID, to: content)

        let trigger: UNNotificationTrigger?

        if let deadline {
            trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, deadline.timeIntervalSinceNow),
                repeats: false
            )
        } else {
            trigger = nil
        }


        send(
            identifier:
                "safewalk-missed",

            content:
                content,

            trigger:
                trigger
        )
    }


    func cancelPendingMissedCheckInNotification() {

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers: ["safewalk-missed"]
            )
    }


    private func addJourneyID(
        _ journeyID: UUID?,
        to content: UNMutableNotificationContent
    ) {

        guard let journeyID else {
            return
        }

        content.userInfo["safeWalkJourneyID"] = journeyID.uuidString
    }


    // MARK: - Send Notification

    private func send(
        identifier: String,
        content:
            UNNotificationContent,
        trigger: UNNotificationTrigger? = nil
    ) {

        /*
         Don't attempt to send a user-facing
         notification if permission is known
         to be denied.
         */

        guard authorizationStatus != .denied
        else {

            return
        }


        let request =
            UNNotificationRequest(
                identifier:
                    identifier,

                content:
                    content,

                trigger:
                    trigger
            )


        UNUserNotificationCenter
            .current()
            .add(request)
    }
}
