import Foundation
import Combine
import SwiftUI

struct JourneyRecord: Identifiable, Codable {

    let id: UUID

    let destination: String

    let startDate: Date
    let endDate: Date

    let plannedDistance: Double

    let completedSuccessfully: Bool

    let wentOffRoute: Bool
    let checkInTriggered: Bool
    let checkInExpired: Bool

    // MARK: - Calculated Values

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var durationMinutes: Int {
        max(0, Int(duration / 60))
    }

    var distanceKilometres: Double {
        plannedDistance / 1000
    }
}


final class JourneyHistoryManager: ObservableObject {

    @Published private(set) var journeys: [JourneyRecord] = []

    private let storageKey = "journeyHistoryV2"

    init() {
        loadHistory()
    }


    // MARK: - Add Journey

    func addJourney(
        destination: String,
        startDate: Date,
        endDate: Date = Date(),
        plannedDistance: Double,
        completedSuccessfully: Bool,
        wentOffRoute: Bool,
        checkInTriggered: Bool,
        checkInExpired: Bool
    ) {

        let record = JourneyRecord(
            id: UUID(),
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            plannedDistance: plannedDistance,
            completedSuccessfully: completedSuccessfully,
            wentOffRoute: wentOffRoute,
            checkInTriggered: checkInTriggered,
            checkInExpired: checkInExpired
        )

        journeys.insert(record, at: 0)

        saveHistory()
    }


    // MARK: - Delete Journey

    func deleteJourney(at offsets: IndexSet) {

        journeys.remove(atOffsets: offsets)

        saveHistory()
    }


    // MARK: - Clear History

    func clearHistory() {

        journeys.removeAll()

        UserDefaults.standard.removeObject(
            forKey: storageKey
        )
    }


    // MARK: - Save

    private func saveHistory() {

        do {

            let data = try JSONEncoder()
                .encode(journeys)

            UserDefaults.standard.set(
                data,
                forKey: storageKey
            )

        } catch {

            print(
                "Failed to save journey history:",
                error
            )
        }
    }


    // MARK: - Load

    private func loadHistory() {

        guard let data =
                UserDefaults.standard.data(
                    forKey: storageKey
                )
        else {
            return
        }

        do {

            journeys = try JSONDecoder()
                .decode(
                    [JourneyRecord].self,
                    from: data
                )

        } catch {

            print(
                "Failed to load journey history:",
                error
            )
        }
    }
}
