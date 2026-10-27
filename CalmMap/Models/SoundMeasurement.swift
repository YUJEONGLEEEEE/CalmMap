import Foundation
import SwiftData

@Model
final class SoundMeasurement {
    var id: UUID
    var placeCode: String
    var measuredAt: Date
    var durationSeconds: Int
    var ratioData: Data
    var averageDecibels: Double
    var peakDecibels: Double
    var soundScore: Double
    var brightLight: Bool
    var flicker: Bool

    init(
        placeCode: String,
        measuredAt: Date,
        durationSeconds: Int,
        ratios: [SoundCategory: Double],
        averageDecibels: Double,
        peakDecibels: Double,
        soundScore: Double,
        brightLight: Bool = false,
        flicker: Bool = false
    ) {
        self.id = UUID()
        self.placeCode = placeCode
        self.measuredAt = measuredAt
        self.durationSeconds = durationSeconds
        self.ratioData = (try? JSONEncoder().encode(Dictionary(uniqueKeysWithValues: ratios.map { ($0.key.rawValue, $0.value) }))) ?? Data()
        self.averageDecibels = averageDecibels
        self.peakDecibels = peakDecibels
        self.soundScore = soundScore
        self.brightLight = brightLight
        self.flicker = flicker
    }

    var ratios: [SoundCategory: Double] {
        guard let raw = try? JSONDecoder().decode([String: Double].self, from: ratioData) else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
            SoundCategory(rawValue: key).map { ($0, value) }
        })
    }
}

enum MeasuredSound {
    static let windowHours = 2

    static func pool(for placeCode: String, at date: Date, in measurements: [SoundMeasurement], calendar: Calendar = .seoul) -> [SoundMeasurement] {
        let forPlace = measurements.filter { $0.placeCode == placeCode }
        let targetHour = calendar.component(.hour, from: date)
        let nearby = forPlace.filter {
            let hour = calendar.component(.hour, from: $0.measuredAt)
            let diff = abs(hour - targetHour)
            return min(diff, 24 - diff) <= windowHours
        }
        return nearby.isEmpty ? forPlace : nearby
    }

    static func score(for placeCode: String, at date: Date, in measurements: [SoundMeasurement], calendar: Calendar = .seoul) -> Double? {
        let pool = pool(for: placeCode, at: date, in: measurements, calendar: calendar)
        guard !pool.isEmpty else { return nil }
        return pool.map(\.soundScore).reduce(0, +) / Double(pool.count)
    }

    static func ratios(of pool: [SoundMeasurement]) -> [SoundCategory: Double] {
        guard !pool.isEmpty else { return [:] }
        var total: [SoundCategory: Double] = [:]
        for measurement in pool {
            for (category, ratio) in measurement.ratios {
                total[category, default: 0] += ratio
            }
        }
        return total.mapValues { $0 / Double(pool.count) }
    }
}
