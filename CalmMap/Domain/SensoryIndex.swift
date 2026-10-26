import Foundation

enum SensoryTier: Int, CaseIterable, Comparable {
    case calm
    case moderate
    case intense

    init(score: Double) {
        switch score {
        case ..<40: self = .calm
        case ..<65: self = .moderate
        default: self = .intense
        }
    }

    var title: String {
        switch self {
        case .calm: "무던함"
        case .moderate: "보통"
        case .intense: "붐빔"
        }
    }

    var symbolName: String {
        switch self {
        case .calm: "circle"
        case .moderate: "circle.lefthalf.filled"
        case .intense: "circle.fill"
        }
    }

    static func < (lhs: SensoryTier, rhs: SensoryTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct SensoryReading: Hashable {
    let score: Double
    let crowd: Double
    let sound: Double
    let soundIsEstimated: Bool

    var tier: SensoryTier { SensoryTier(score: score) }
}

enum SensoryIndex {
    static let crowdWeight = 0.6
    static let soundWeight = 0.4
    static let densityWeight = 0.6
    static let levelWeight = 0.4
    static let densityFloor = 1.0
    static let densityCeiling = 150.0

    static func densityScore(population: Double, areaSquareMeters: Double) -> Double {
        guard areaSquareMeters > 0 else { return 0 }
        let perThousand = max(population / areaSquareMeters * 1000, densityFloor)
        let scaled = log10(perThousand / densityFloor) / log10(densityCeiling / densityFloor)
        return min(max(scaled, 0), 1)
    }

    static func crowdScore(population: Double, level: CongestionLevel, areaSquareMeters: Double) -> Double {
        let density = densityScore(population: population, areaSquareMeters: areaSquareMeters)
        let relative = level.rank / 3
        return densityWeight * density + levelWeight * relative
    }

    static func estimatedSound(for category: String) -> Double {
        switch category {
        case "공원": 0.25
        case "고궁·문화유산": 0.35
        case "발달상권": 0.6
        case "인구밀집지역": 0.65
        case "관광특구": 0.7
        default: 0.5
        }
    }

    static func reading(
        place: Place,
        population: Double,
        level: CongestionLevel,
        measuredSound: Double? = nil
    ) -> SensoryReading {
        let crowd = crowdScore(population: population, level: level, areaSquareMeters: place.areaSquareMeters)
        let sound = measuredSound ?? estimatedSound(for: place.category)
        let score = (crowdWeight * crowd + soundWeight * sound) * 100
        return SensoryReading(
            score: min(max(score, 0), 100),
            crowd: crowd,
            sound: sound,
            soundIsEstimated: measuredSound == nil
        )
    }
}

struct HourlyReading: Identifiable, Hashable {
    let date: Date
    let reading: SensoryReading

    var id: Date { date }
}

enum CalmWindowAdvisor {
    static func hourly(place: Place, live: LivePlace, soundAt: (Date) -> Double? = { _ in nil }) -> [HourlyReading] {
        live.forecast.compactMap { point in
            guard let date = point.date else { return nil }
            let reading = SensoryIndex.reading(
                place: place,
                population: point.populationMid,
                level: point.level,
                measuredSound: soundAt(date)
            )
            return HourlyReading(date: date, reading: reading)
        }
    }

    static func advice(current: SensoryReading, hourly: [HourlyReading], calendar: Calendar = .seoul) -> String {
        if current.tier == .calm {
            return "지금은 무던한 편이에요."
        }
        guard let firstCalm = hourly.first(where: { $0.reading.tier == .calm }) else {
            if let best = hourly.min(by: { $0.reading.score < $1.reading.score }), best.reading.score < current.score {
                return "앞으로 12시간 중 \(hourText(best.date, calendar: calendar))이 가장 덜 붐빌 것 같아요."
            }
            return "앞으로 12시간 동안 무던한 시간대가 예상되지 않아요."
        }
        return "\(dayPrefix(firstCalm.date, calendar: calendar))\(hourText(firstCalm.date, calendar: calendar)) 이후가 무던할 것 같아요."
    }

    private static func hourText(_ date: Date, calendar: Calendar) -> String {
        "\(calendar.component(.hour, from: date))시"
    }

    private static func dayPrefix(_ date: Date, calendar: Calendar) -> String {
        calendar.isDateInToday(date) ? "오늘은 " : "내일 "
    }
}

extension Calendar {
    static var seoul: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }
}
