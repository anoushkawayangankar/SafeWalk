import Foundation
import Combine

final class PeriodicCheckInManager: ObservableObject {

    // MARK: - Published State

    @Published var isRunning = false
    @Published var secondsUntilNextCheckIn = 60


    // MARK: - Configuration

    private let interval: TimeInterval = 60


    // MARK: - Timer State

    private var timer: Timer?

    private var nextCheckInDate: Date?

    private var onCheckInRequired:
        (() -> Void)?


    // MARK: - Persistence

    private let defaults =
        UserDefaults.standard

    private enum Keys {

        static let isRunning =
            "safeWalkPeriodicCheckInIsRunning"

        static let nextCheckInDate =
            "safeWalkPeriodicNextCheckInDate"
    }


    // MARK: - Init

    init() {

        restorePersistedState()
    }


    // MARK: - Start

    func start(
        onCheckInRequired:
            @escaping () -> Void
    ) {

        /*
         Always update the callback.

         Closures cannot be persisted, so after
         a cold launch JourneyTrackingService
         needs to reconnect it.
         */

        self.onCheckInRequired =
            onCheckInRequired


        /*
         If a valid periodic cycle was restored
         from disk, continue that cycle instead
         of creating a new 60-second deadline.
         */

        if isRunning {

            restoreOrResumeCycle()

            return
        }


        isRunning =
            true


        scheduleNextCheckIn()


    }


    // MARK: - Schedule Next Check-In

    private func scheduleNextCheckIn() {

        timer?.invalidate()
        timer = nil


        nextCheckInDate =
            Date()
                .addingTimeInterval(
                    interval
                )


        secondsUntilNextCheckIn =
            Int(interval)


        persistState()


        startTimer()
    }


    // MARK: - Timer

    private func startTimer() {

        guard isRunning else {
            return
        }


        timer?.invalidate()
        timer = nil


        DispatchQueue.main.async { [weak self] in

            guard let self else {
                return
            }


            guard self.isRunning else {
                return
            }


            self.updateCountdown()


            guard
                self.isRunning,
                self.nextCheckInDate != nil
            else {
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

        guard isRunning else {
            return
        }


        guard let nextCheckInDate else {

            /*
             Running without a deadline is
             invalid. Create a fresh cycle.
             */

            scheduleNextCheckIn()

            return
        }


        let remaining =
            nextCheckInDate
                .timeIntervalSinceNow


        if remaining <= 0 {

            secondsUntilNextCheckIn =
                0


            triggerCheckIn()

            return
        }


        secondsUntilNextCheckIn =
            max(
                1,
                Int(
                    ceil(
                        remaining
                    )
                )
            )
    }


    // MARK: - Trigger

    private func triggerCheckIn() {

        guard isRunning else {
            return
        }


        timer?.invalidate()
        timer = nil


        /*
         Remove the deadline before calling the
         callback.

         We are now waiting for the safety
         check-in to be completed before another
         periodic cycle should be scheduled.
         */

        nextCheckInDate =
            nil

        secondsUntilNextCheckIn =
            0


        persistState()


        onCheckInRequired?()
    }


    // MARK: - Restart Cycle

    func checkInCompleted() {

        guard isRunning else {
            return
        }


        scheduleNextCheckIn()
    }


    func recoverInterruptedTriggerIfNeeded(
        hasUnresolvedCheckIn: Bool
    ) {

        guard
            isRunning,
            nextCheckInDate == nil,
            !hasUnresolvedCheckIn
        else {
            return
        }

        scheduleNextCheckIn()
    }


    // MARK: - Background

    func appDidEnterBackground() {

        guard isRunning else {
            return
        }


        /*
         Do not modify nextCheckInDate.

         It is an absolute deadline, so elapsed
         time continues while SafeWalk is in the
         background.
         */

        timer?.invalidate()
        timer = nil


        persistState()
    }


    // MARK: - Foreground

    func appDidBecomeActive() {

        guard isRunning else {
            return
        }


        restoreOrResumeCycle()
    }


    // MARK: - Restore / Resume

    private func restoreOrResumeCycle() {

        guard isRunning else {
            return
        }


        /*
         A nil deadline means the periodic
         deadline already fired and the manager
         is waiting for the associated check-in
         to finish.

         Do NOT create another periodic timer.
         */

        guard let nextCheckInDate else {

            secondsUntilNextCheckIn =
                0

            return
        }


        if nextCheckInDate <= Date() {

            secondsUntilNextCheckIn =
                0


            triggerCheckIn()

            return
        }


        let remaining =
            nextCheckInDate
                .timeIntervalSinceNow


        secondsUntilNextCheckIn =
            max(
                1,
                Int(
                    ceil(
                        remaining
                    )
                )
            )


        startTimer()
    }


    // MARK: - Restore Persistence

    private func restorePersistedState() {

        timer?.invalidate()
        timer = nil


        let storedRunning =
            defaults.bool(
                forKey:
                    Keys.isRunning
            )


        guard storedRunning else {

            isRunning =
                false

            nextCheckInDate =
                nil

            secondsUntilNextCheckIn =
                Int(interval)

            return
        }


        isRunning =
            true


        nextCheckInDate =
            defaults.object(
                forKey:
                    Keys.nextCheckInDate
            ) as? Date


        /*
         Do not trigger anything here.

         At init time JourneyTrackingService has
         not yet supplied onCheckInRequired.

         start(...) will reconnect the callback
         and then evaluate the deadline.
         */

        if let nextCheckInDate {

            let remaining =
                nextCheckInDate
                    .timeIntervalSinceNow


            if remaining > 0 {

                secondsUntilNextCheckIn =
                    max(
                        1,
                        Int(
                            ceil(
                                remaining
                            )
                        )
                    )

            } else {

                secondsUntilNextCheckIn =
                    0
            }

        } else {

            /*
             nil means the previous deadline
             already fired and the system was
             waiting for that check-in.
             */

            secondsUntilNextCheckIn =
                0
        }
    }


    // MARK: - Persistence

    private func persistState() {

        defaults.set(
            isRunning,
            forKey:
                Keys.isRunning
        )


        if let nextCheckInDate {

            defaults.set(
                nextCheckInDate,
                forKey:
                    Keys.nextCheckInDate
            )

        } else {

            defaults.removeObject(
                forKey:
                    Keys.nextCheckInDate
            )
        }
    }


    // MARK: - Stop

    func stop() {

        timer?.invalidate()
        timer = nil


        nextCheckInDate =
            nil

        onCheckInRequired =
            nil


        isRunning =
            false


        secondsUntilNextCheckIn =
            Int(interval)


        clearPersistedState()
    }


    // MARK: - Clear Persistence

    private func clearPersistedState() {

        defaults.removeObject(
            forKey:
                Keys.isRunning
        )


        defaults.removeObject(
            forKey:
                Keys.nextCheckInDate
        )
    }
}
