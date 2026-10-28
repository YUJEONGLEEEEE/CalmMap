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
    let soundSource: SoundSource
    var baseScore: Double
    var factors: [PersonalFactor] = []

    var tier: SensoryTier { SensoryTier(score: score) }
    var baseTier: SensoryTier { SensoryTier(score: baseScore) }
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
        context: SoundContext? = nil,
        profile: SensoryProfile = .general
    ) -> SensoryReading {
        let context = context ?? .expected(for: place)
        let crowd = crowdScore(population: population, level: level, areaSquareMeters: place.areaSquareMeters)
        let sound = context.input?.value ?? estimatedSound(for: place.category)
        let baseScore = clamp((crowdWeight * crowd + soundWeight * sound) * 100)
        let personal = PersonalAdjuster.adjust(crowd: crowd, sound: sound, context: context, profile: profile)
        let score = clamp((crowdWeight * personal.crowd + soundWeight * personal.sound) * 100 + personal.penalty)
        return SensoryReading(
            score: score,
            crowd: personal.crowd,
            sound: personal.sound,
            soundSource: context.input?.source ?? .estimate,
            baseScore: baseScore,
            factors: personal.factors
        )
    }

    private static func clamp(_ score: Double) -> Double {
        min(max(score, 0), 100)
    }
}

struct HourlyReading: Identifiable, Hashable {
    let date: Date
    let reading: SensoryReading

    var id: Date { date }
}

enum CalmWindowAdvisor {
    static func hourly(
        place: Place,
        live: LivePlace,
        profile: SensoryProfile = .general,
        contextAt: (Date) -> SoundContext? = { _ in nil }
    ) -> [HourlyReading] {
        live.forecast.compactMap { point in
            guard let date = point.date else { return nil }
            let reading = SensoryIndex.reading(
                place: place,
                population: point.populationMid,
                level: point.level,
                context: contextAt(date),
                profile: profile
            )
            return HourlyReading(date: date, reading: reading)
        }
    }

    static func advice(current: SensoryReading, hourly: [HourlyReading], calendar: Calendar = .seoul) -> String {
        if current.tier == .calm {
            return "지금은 무던한 편이에요."
        }
        guard !hourly.isEmpty else {
            return "이곳은 지금 시간대별 예보가 없어 덜 붐비는 시간을 알려 드리기 어려워요."
        }
        guard let firstCalm = hourly.first(where: { $0.reading.tier == .calm }) else {
            if let best = hourly.min(by: { $0.reading.score < $1.reading.score }), best.reading.score < current.score {
                return "앞으로 12시간 중 \(hourText(best.date, calendar: calendar))가 가장 덜 붐빌 것 같아요."
            }
            return "앞으로 12시간 동안 무던한 시간대가 예상되지 않아요."
        }
        return "\(dayPrefix(firstCalm.date, calendar: calendar))\(hourText(firstCalm.date, calendar: calendar)) 이후가 무던할 것 같아요."
    }

    private static func hourText(_ date: Date, calendar: Calendar) -> String {
        date.seoulHourText
    }

    private static func dayPrefix(_ date: Date, calendar: Calendar) -> String {
        calendar.isDateInToday(date) ? "오늘은 " : "내일 "
    }
}

extension Calendar {
    static var seoul: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .seoul
        return calendar
    }
}

extension TimeZone {
    static let seoul = TimeZone(identifier: "Asia/Seoul") ?? .current
}

extension Date {
    var seoulTimeText: String {
        formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: .seoul))
    }

    var seoulStampText: String {
        guard !Calendar.seoul.isDateInToday(self) else { return seoulTimeText }
        let day = formatted(Date.FormatStyle(timeZone: .seoul).month(.defaultDigits).day())
        return "\(day) \(seoulTimeText)"
    }

    var seoulHourText: String {
        let hour = Calendar.seoul.component(.hour, from: self)
        let display = hour % 12 == 0 ? 12 : hour % 12
        return "\(hour < 12 ? "오전" : "오후") \(display)시"
    }
}
