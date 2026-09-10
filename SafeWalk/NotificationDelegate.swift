import Foundation
import UserNotifications
import Combine

final class NotificationDelegate:
    NSObject,
    ObservableObject,
    UNUserNotificationCenterDelegate {

    static let shared =
        NotificationDelegate()

    let userConfirmedSafe =
        PassthroughSubject<UUID?, Never>()

    private override init() {

        super.init()

        UNUserNotificationCenter
            .current()
            .delegate = self
    }


    // MARK: - Action

    func userNotificationCenter(
        _ center:
            UNUserNotificationCenter,
        didReceive response:
            UNNotificationResponse
    ) async {

        if response.actionIdentifier ==
            NotificationManager.safeAction {

            await MainActor.run {

                let journeyID =
                    response.notification.request.content.userInfo[
                        "safeWalkJourneyID"
                    ] as? String

                self.userConfirmedSafe
                    .send(
                        journeyID.flatMap(UUID.init(uuidString:))
                    )
            }
        }
    }


    // MARK: - Foreground Banner

    func userNotificationCenter(
        _ center:
            UNUserNotificationCenter,
        willPresent notification:
            UNNotification
    ) async
        -> UNNotificationPresentationOptions {

        [
            .banner,
            .sound
        ]
    }
}
