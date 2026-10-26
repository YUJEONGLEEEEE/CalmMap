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

    var observedDate: Date? { CityDataDate.parse(observedAt) }
    var populationMid: Double { (populationMin + populationMax) / 2 }
}

struct CitySnapshot: Codable {
    let updatedAt: String?
    let places: [String: LivePlace]
}

enum CityDataDate {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    static func parse(_ text: String) -> Date? {
        formatter.date(from: text)
    }
}
