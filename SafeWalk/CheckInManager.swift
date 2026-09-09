import Foundation
import Combine

enum CheckInReason: Equatable {
    case offRoute
    case periodic
}

final class CheckInManager: ObservableObject {

    @Published var isCheckInActive = false
    @Published var secondsRemaining = 30
    @Published var didExpire = false
    @Published var reason: CheckInReason?

    private let checkInDuration: TimeInterval = 30

    private var timer: Timer?
    private var expirationDate: Date?

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

        self.reason = reason

        isCheckInActive = true
        didExpire = false

        secondsRemaining =
            Int(checkInDuration)

        expirationDate =
            Date().addingTimeInterval(
                checkInDuration
            )

        timer?.invalidate()
        timer = nil

        print(
            reason == .offRoute
                ? "⏱ Starting OFF-ROUTE check-in"
                : "⏱ Starting PERIODIC check-in"
        )

        startTimer()
    }

    // MARK: - Timer

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

        guard isCheckInActive else {
            return
        }

        guard let expirationDate else {
            return
        }

        let remaining =
            expirationDate.timeIntervalSinceNow

        if remaining <= 0 {

            secondsRemaining = 0

            expireCheckIn()

            return
        }

        secondsRemaining =
            Int(ceil(remaining))

        print(
            "⏱ Check-in:",
            secondsRemaining
        )
    }

    // MARK: - Expiry

    private func expireCheckIn() {

        timer?.invalidate()
        timer = nil

        expirationDate = nil

        secondsRemaining = 0

        isCheckInActive = false

        // Keep reason so the emergency UI knows
        // what caused the missed check-in.

        didExpire = true

        print("⚠️ CHECK-IN EXPIRED")
    }

    // MARK: - Safe

    func confirmSafe() {

        timer?.invalidate()
        timer = nil

        expirationDate = nil

        isCheckInActive = false
        didExpire = false

        secondsRemaining =
            Int(checkInDuration)

        reason = nil

        print("✅ User confirmed safe")
    }

    // MARK: - Background

    func appDidEnterBackground() {

        guard isCheckInActive else {
            return
        }

        timer?.invalidate()
        timer = nil
    }

    // MARK: - Foreground

    func appDidBecomeActive() {

        guard isCheckInActive else {
            return
        }

        guard let expirationDate else {
            return
        }

        if expirationDate <= Date() {

            secondsRemaining = 0

            expireCheckIn()

            return
        }

        updateCountdown()

        startTimer()
    }

    // MARK: - Reset

    func reset() {

        timer?.invalidate()
        timer = nil

        expirationDate = nil

        isCheckInActive = false
        didExpire = false

        secondsRemaining =
            Int(checkInDuration)

        reason = nil
    }
}
