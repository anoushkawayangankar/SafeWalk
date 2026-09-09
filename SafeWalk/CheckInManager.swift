import Foundation
import Combine

enum CheckInReason: String, Equatable {
    case offRoute
    case periodic
}


final class CheckInManager: ObservableObject {

    // MARK: - Published State

    @Published var isCheckInActive = false
    @Published var secondsRemaining = 30
    @Published var didExpire = false
    @Published var reason: CheckInReason?


    // MARK: - Configuration

    private let checkInDuration:
        TimeInterval = 30


    // MARK: - Timer

    private var timer: Timer?

    private var expirationDate:
        Date?


    // MARK: - Persistence

    private let defaults =
        UserDefaults.standard


    private enum Keys {

        static let isActive =
            "safeWalkCheckInIsActive"

        static let expirationDate =
            "safeWalkCheckInExpirationDate"

        static let reason =
            "safeWalkCheckInReason"

        static let didExpire =
            "safeWalkCheckInDidExpire"
    }


    // MARK: - Init

    init() {

        restorePersistedState()
    }


    // MARK: - Start

    func startCheckIn(
        reason: CheckInReason
    ) {

        guard !isCheckInActive else {
            return
        }

        guard !didExpire else {
            return
        }


        timer?.invalidate()
        timer = nil


        self.reason =
            reason

        isCheckInActive =
            true

        didExpire =
            false

        secondsRemaining =
            Int(checkInDuration)

        expirationDate =
            Date()
                .addingTimeInterval(
                    checkInDuration
                )


        persistState()


        print(
            reason == .offRoute
                ? "⏱ Starting OFF-ROUTE check-in"
                : "⏱ Starting PERIODIC check-in"
        )


        startTimer()
    }


    // MARK: - Timer

    private func startTimer() {

        guard isCheckInActive else {
            return
        }


        timer?.invalidate()
        timer = nil


        DispatchQueue.main.async { [weak self] in

            guard let self else {
                return
            }


            /*
             State could have changed while
             waiting for the main queue.
             */

            guard self.isCheckInActive else {
                return
            }


            self.updateCountdown()


            guard self.isCheckInActive else {
                return
            }


            let timer =
                Timer(
                    timeInterval: 1,
                    repeats: true
                ) { [weak self] _ in

                    self?
                        .updateCountdown()
                }


            self.timer =
                timer


            RunLoop.main.add(
                timer,
                forMode:
                    .common
            )
        }
    }


    // MARK: - Update Countdown

    private func updateCountdown() {

        guard isCheckInActive else {
            return
        }


        guard let expirationDate else {

            /*
             An active check-in without a
             deadline is invalid state.
             */

            expireCheckIn()

            return
        }


        let remaining =
            expirationDate
                .timeIntervalSinceNow


        if remaining <= 0 {

            secondsRemaining =
                0

            expireCheckIn()

            return
        }


        secondsRemaining =
            Int(
                ceil(
                    remaining
                )
            )


        print(
            "⏱ Check-in:",
            secondsRemaining
        )
    }


    // MARK: - Expiry

    private func expireCheckIn() {

        timer?.invalidate()
        timer = nil


        expirationDate =
            nil

        secondsRemaining =
            0

        isCheckInActive =
            false

        /*
         Keep the reason.

         This allows SafeWalk to know whether
         the missed check-in was caused by an
         off-route event or a periodic check.
         */

        didExpire =
            true


        persistState()


        print(
            "⚠️ CHECK-IN EXPIRED"
        )
    }


    // MARK: - Confirm Safe

    func confirmSafe() {

        timer?.invalidate()
        timer = nil


        expirationDate =
            nil

        isCheckInActive =
            false

        didExpire =
            false

        secondsRemaining =
            Int(checkInDuration)

        reason =
            nil


        clearPersistedState()


        print(
            "✅ User confirmed safe"
        )
    }


    // MARK: - Background

    func appDidEnterBackground() {

        guard isCheckInActive else {
            return
        }


        /*
         Do not change expirationDate.

         The deadline is absolute, so time
         continues passing while SafeWalk is
         in the background.
         */

        timer?.invalidate()
        timer = nil


        persistState()
    }


    // MARK: - Foreground

    func appDidBecomeActive() {

        /*
         Re-read persisted data first.

         This also makes this function safe if
         the manager survived an unusual scene
         lifecycle transition.
         */

        if !isCheckInActive &&
            !didExpire {

            restorePersistedState()
        }


        if didExpire {

            secondsRemaining =
                0

            return
        }


        guard isCheckInActive else {
            return
        }


        guard let expirationDate else {

            expireCheckIn()

            return
        }


        if expirationDate <= Date() {

            secondsRemaining =
                0

            expireCheckIn()

            return
        }


        updateCountdown()

        startTimer()
    }


    // MARK: - Restore Persistence

    private func restorePersistedState() {

        timer?.invalidate()
        timer = nil


        let storedActive =
            defaults.bool(
                forKey:
                    Keys.isActive
            )

        let storedExpired =
            defaults.bool(
                forKey:
                    Keys.didExpire
            )

        let storedExpiration =
            defaults.object(
                forKey:
                    Keys.expirationDate
            ) as? Date

        let storedReasonRaw =
            defaults.string(
                forKey:
                    Keys.reason
            )

        let storedReason =
            storedReasonRaw
                .flatMap {
                    CheckInReason(
                        rawValue:
                            $0
                    )
                }


        // MARK: Previously Expired

        if storedExpired {

            isCheckInActive =
                false

            didExpire =
                true

            secondsRemaining =
                0

            expirationDate =
                nil

            reason =
                storedReason

            return
        }


        // MARK: No Active Check-In

        guard storedActive else {

            isCheckInActive =
                false

            didExpire =
                false

            secondsRemaining =
                Int(checkInDuration)

            expirationDate =
                nil

            reason =
                nil

            return
        }


        /*
         An active persisted check-in must have
         both a valid deadline and a reason.
         */

        guard
            let storedExpiration,
            let storedReason
        else {

            clearPersistedState()

            resetInMemoryState()

            return
        }


        reason =
            storedReason

        expirationDate =
            storedExpiration


        // MARK: Expired While App Was Terminated

        if storedExpiration <= Date() {

            isCheckInActive =
                false

            didExpire =
                true

            secondsRemaining =
                0

            expirationDate =
                nil


            persistState()


            print(
                "⚠️ Persisted check-in expired while app was closed"
            )

            return
        }


        // MARK: Restore Active Countdown

        isCheckInActive =
            true

        didExpire =
            false


        let remaining =
            storedExpiration
                .timeIntervalSinceNow


        secondsRemaining =
            max(
                1,
                Int(
                    ceil(
                        remaining
                    )
                )
            )


        print(
            "♻️ Restored check-in with",
            secondsRemaining,
            "seconds remaining"
        )


        startTimer()
    }


    // MARK: - Persist State

    private func persistState() {

        defaults.set(
            isCheckInActive,
            forKey:
                Keys.isActive
        )


        defaults.set(
            didExpire,
            forKey:
                Keys.didExpire
        )


        if let expirationDate {

            defaults.set(
                expirationDate,
                forKey:
                    Keys.expirationDate
            )

        } else {

            defaults.removeObject(
                forKey:
                    Keys.expirationDate
            )
        }


        if let reason {

            defaults.set(
                reason.rawValue,
                forKey:
                    Keys.reason
            )

        } else {

            defaults.removeObject(
                forKey:
                    Keys.reason
            )
        }
    }


    // MARK: - Clear Persistence

    private func clearPersistedState() {

        defaults.removeObject(
            forKey:
                Keys.isActive
        )

        defaults.removeObject(
            forKey:
                Keys.expirationDate
        )

        defaults.removeObject(
            forKey:
                Keys.reason
        )

        defaults.removeObject(
            forKey:
                Keys.didExpire
        )
    }


    // MARK: - Reset In-Memory State

    private func resetInMemoryState() {

        timer?.invalidate()
        timer = nil

        expirationDate =
            nil

        isCheckInActive =
            false

        didExpire =
            false

        secondsRemaining =
            Int(checkInDuration)

        reason =
            nil
    }


    // MARK: - Reset

    func reset() {

        resetInMemoryState()

        clearPersistedState()
    }
}
