import Foundation
import SwiftData

@Model
final class ChildProfile {
    var id: UUID
    var name: String
    var crowdLevel: Int
    var loudnessLevel: Int
    var triggerData: Data
    var brightLightSensitive: Bool
    var flickerSensitive: Bool
    var note: String
    var createdAt: Date

    init(
        name: String,
        crowd: Sensitivity = .usual,
        loudness: Sensitivity = .usual,
        triggers: [SoundCategory: TriggerLevel] = [:],
        brightLightSensitive: Bool = false,
        flickerSensitive: Bool = false,
        note: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.crowdLevel = crowd.rawValue
        self.loudnessLevel = loudness.rawValue
        self.triggerData = Self.encode(triggers)
        self.brightLightSensitive = brightLightSensitive
        self.flickerSensitive = flickerSensitive
        self.note = note
        self.createdAt = Date()
    }

    var crowd: Sensitivity {
        get { Sensitivity(rawValue: crowdLevel) ?? .usual }
        set { crowdLevel = newValue.rawValue }
    }

    var loudness: Sensitivity {
        get { Sensitivity(rawValue: loudnessLevel) ?? .usual }
        set { loudnessLevel = newValue.rawValue }
    }

    var triggers: [SoundCategory: TriggerLevel] {
        get {
            guard let raw = try? JSONDecoder().decode([String: Int].self, from: triggerData) else { return [:] }
            return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
                guard let category = SoundCategory(rawValue: key), let level = TriggerLevel(rawValue: value) else { return nil }
                return (category, level)
            })
        }
        set { triggerData = Self.encode(newValue) }
    }

    var sensoryProfile: SensoryProfile {
        SensoryProfile(
            name: name,
            crowd: crowd,
            loudness: loudness,
            triggers: triggers,
            brightLightSensitive: brightLightSensitive,
            flickerSensitive: flickerSensitive
        )
    }

    private static func encode(_ triggers: [SoundCategory: TriggerLevel]) -> Data {
        let raw = Dictionary(uniqueKeysWithValues: triggers.map { ($0.key.rawValue, $0.value.rawValue) })
        return (try? JSONEncoder().encode(raw)) ?? Data()
    }
}

enum Sensitivity: Int, CaseIterable, Identifiable, Codable {
    case low
    case usual
    case high

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low: "덜 예민해요"
        case .usual: "보통이에요"
        case .high: "예민해요"
        }
    }

    var multiplier: Double {
        switch self {
        case .low: 0.75
        case .usual: 1.0
        case .high: 1.35
        }
    }
}

enum TriggerLevel: Int, CaseIterable, Identifiable, Codable {
    case fine
    case some
    case strong

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fine: "괜찮아요"
        case .some: "조금 힘들어해요"
        case .strong: "많이 힘들어해요"
        }
    }

    var shortTitle: String {
        switch self {
        case .fine: "괜찮음"
        case .some: "조금"
        case .strong: "많이"
        }
    }

    var boost: Double {
        switch self {
        case .fine: 0
        case .some: 0.6
        case .strong: 1.2
        }
    }
}

extension SoundCategory {
    static let triggerCandidates: [SoundCategory] = [.suddenLoud, .chime, .crowd, .babyCrying, .traffic, .music]
}
