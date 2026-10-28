import Foundation

struct NoiseBaseline: Decodable {
    struct Profile: Decodable {
        let sensors: Int
        let weekday: [Double?]
        let weekend: [Double?]
    }

    let places: [String: Profile]

    static let shared: NoiseBaseline? = {
        guard let url = Bundle.main.url(forResource: "noise_baseline", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(NoiseBaseline.self, from: data)
    }()

    func decibels(for placeCode: String, at date: Date, calendar: Calendar = .seoul) -> (decibels: Double, sensors: Int)? {
        guard let profile = places[placeCode] else { return nil }
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        let series = isWeekend ? profile.weekend : profile.weekday
        guard series.indices.contains(hour), let value = series[hour] else { return nil }
        return (value, profile.sensors)
    }
}

enum SoundSource: Hashable {
    case measured
    case sensor(decibels: Double, sensors: Int)
    case estimate
}

struct SoundInput: Hashable {
    let value: Double
    let source: SoundSource

    static let quietSensorDecibels: Double = 35
    static let loudSensorDecibels: Double = 65

    static func sensor(decibels: Double, sensors: Int) -> SoundInput {
        let scaled = (decibels - quietSensorDecibels) / (loudSensorDecibels - quietSensorDecibels)
        return SoundInput(value: min(max(scaled, 0), 1), source: .sensor(decibels: decibels, sensors: sensors))
    }
}
