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
        PassthroughSubject<Void, Never>()

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

                self.userConfirmedSafe
                    .send()
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
