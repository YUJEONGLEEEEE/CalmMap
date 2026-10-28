import Foundation

enum CongestionLevel: String, Codable, CaseIterable {
    case relaxed = "여유"
    case normal = "보통"
    case slightlyBusy = "약간 붐빔"
    case busy = "붐빔"

    var rank: Double {
        switch self {
        case .relaxed: 0
        case .normal: 1
        case .slightlyBusy: 2
        case .busy: 3
        }
    }
}

struct ForecastPoint: Codable, Hashable {
    let time: String
    let level: CongestionLevel
    let populationMin: Double
    let populationMax: Double

    var date: Date? { CityDataDate.parse(time) }
    var populationMid: Double { (populationMin + populationMax) / 2 }
}

struct LivePlace: Codable, Hashable {
    let code: String
    let name: String
    let level: CongestionLevel
    let message: String
    let populationMin: Double
    let populationMax: Double
    let observedAt: String
    let forecast: [ForecastPoint]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        level = try container.decode(CongestionLevel.self, forKey: .level)
        message = try container.decode(String.self, forKey: .message)
        populationMin = try container.decode(Double.self, forKey: .populationMin)
        populationMax = try container.decode(Double.self, forKey: .populationMax)
        observedAt = try container.decode(String.self, forKey: .observedAt)
        forecast = (try? container.decode([Lossy<ForecastPoint>].self, forKey: .forecast))?.compactMap(\.value) ?? []
    }

    var observedDate: Date? { CityDataDate.parse(observedAt) }
    var populationMid: Double { (populationMin + populationMax) / 2 }
}

struct CitySnapshot: Codable {
    let updatedAt: String?
    let places: [String: LivePlace]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        places = try container.decode([String: Lossy<LivePlace>].self, forKey: .places).compactMapValues(\.value)
    }
}

private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

enum CityDataDate {
    private static let formatters: [DateFormatter] = ["yyyy-MM-dd HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyyMMddHHmm"].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = format
        return formatter
    }

    static func parse(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        for formatter in formatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }
}
