import Foundation
import Combine

final class PeriodicCheckInManager: ObservableObject {

    @Published var isRunning = false
    @Published var secondsUntilNextCheckIn = 60

    private let interval: TimeInterval = 60

    private var timer: Timer?
    private var nextCheckInDate: Date?

    private var onCheckInRequired:
        (() -> Void)?

    // MARK: - Start

    func start(
        onCheckInRequired:
            @escaping () -> Void
    ) {

        guard !isRunning else {
            return
        }

        self.onCheckInRequired =
            onCheckInRequired

        isRunning = true

        scheduleNextCheckIn()

        print(
            "⏰ Periodic checks started"
        )
    }

    // MARK: - Schedule

    private func scheduleNextCheckIn() {

        timer?.invalidate()
        timer = nil

        nextCheckInDate =
            Date().addingTimeInterval(
                interval
            )

        secondsUntilNextCheckIn =
            Int(interval)

        startTimer()
    }

    private func startTimer() {

        DispatchQueue.main.async { [weak self] in

            guard let self else {
                return
            }

            self.timer?.invalidate()

            let timer = Timer(
                timeInterval: 1,
                repeats: true
            ) { [weak self] _ in

                self?.updateCountdown()
            }

            self.timer = timer

            RunLoop.main.add(
                timer,
                forMode: .common
            )
        }
    }

    private func updateCountdown() {

        guard isRunning else {
            return
        }

        guard let nextCheckInDate else {
            return
        }

        let remaining =
            nextCheckInDate.timeIntervalSinceNow

        if remaining <= 0 {

            secondsUntilNextCheckIn = 0

            triggerCheckIn()

            return
        }

        secondsUntilNextCheckIn =
            Int(ceil(remaining))
    }

    private func triggerCheckIn() {

        timer?.invalidate()
        timer = nil

        print(
            "⏰ PERIODIC CHECK-IN REQUIRED"
        )

        onCheckInRequired?()
    }

    // MARK: - Restart Cycle

    func checkInCompleted() {

        guard isRunning else {
            return
        }

        scheduleNextCheckIn()
    }

    // MARK: - Background

    func appDidEnterBackground() {

        guard isRunning else {
            return
        }

        timer?.invalidate()
        timer = nil
    }

    // MARK: - Foreground

    func appDidBecomeActive() {

        guard isRunning else {
            return
        }

        guard let nextCheckInDate else {

            scheduleNextCheckIn()

            return
        }

        if nextCheckInDate <= Date() {

            secondsUntilNextCheckIn = 0

            triggerCheckIn()

            return
        }

        updateCountdown()

        startTimer()
    }

    // MARK: - Stop

    func stop() {

        timer?.invalidate()
        timer = nil

        nextCheckInDate = nil
        onCheckInRequired = nil

        isRunning = false

        secondsUntilNextCheckIn =
            Int(interval)
    }
}
