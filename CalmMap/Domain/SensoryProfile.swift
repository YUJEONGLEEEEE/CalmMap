import Foundation

struct SensoryProfile: Hashable {
    var name: String?
    var crowd: Sensitivity = .usual
    var loudness: Sensitivity = .usual
    var triggers: [SoundCategory: TriggerLevel] = [:]
    var brightLightSensitive = false
    var flickerSensitive = false

    static let general = SensoryProfile()

    var isGeneral: Bool { name == nil }

    var displayName: String { name ?? "일반" }

    func trigger(_ category: SoundCategory) -> TriggerLevel {
        triggers[category] ?? .fine
    }

    var highlights: [String] {
        var items: [String] = []
        if crowd == .high { items.append("사람 붐빔에 예민") }
        if loudness == .high { items.append("큰 소리에 예민") }
        for category in SoundCategory.triggerCandidates where trigger(category) != .fine {
            items.append("\(category.title) \(trigger(category).shortTitle)")
        }
        if brightLightSensitive { items.append("밝은 조명") }
        if flickerSensitive { items.append("깜빡이는 조명") }
        return items
    }
}

struct SoundContext {
    var input: SoundInput?
    var ratios: [SoundCategory: Double]
    var ratiosMeasured: Bool
    var brightLight: Bool
    var flicker: Bool

    static func expected(for place: Place) -> SoundContext {
        SoundContext(input: nil, ratios: ExpectedSoundMix.ratios(for: place.category), ratiosMeasured: false, brightLight: false, flicker: false)
    }
}

enum ExpectedSoundMix {
    static func ratios(for category: String) -> [SoundCategory: Double] {
        switch category {
        case "공원":
            [.crowd: 0.25, .babyCrying: 0.05, .traffic: 0.1, .music: 0.05, .quiet: 0.5, .other: 0.05]
        case "고궁·문화유산":
            [.crowd: 0.35, .chime: 0.05, .traffic: 0.1, .quiet: 0.4, .other: 0.1]
        case "발달상권":
            [.crowd: 0.35, .music: 0.2, .traffic: 0.2, .chime: 0.05, .suddenLoud: 0.05, .other: 0.15]
        case "인구밀집지역":
            [.crowd: 0.35, .traffic: 0.25, .chime: 0.1, .suddenLoud: 0.08, .music: 0.07, .other: 0.15]
        case "관광특구":
            [.crowd: 0.4, .music: 0.2, .traffic: 0.15, .chime: 0.05, .suddenLoud: 0.05, .other: 0.15]
        default:
            [.crowd: 0.3, .traffic: 0.2, .music: 0.1, .other: 0.4]
        }
    }
}

struct PersonalFactor: Hashable, Identifiable {
    let symbolName: String
    let text: String

    var id: String { text }
}

enum PersonalAdjuster {
    static let brightLightPenalty = 6.0
    static let flickerPenalty = 10.0
    static let noticeableRatio = 0.12

    static func adjust(crowd: Double, sound: Double, context: SoundContext, profile: SensoryProfile) -> (crowd: Double, sound: Double, penalty: Double, factors: [PersonalFactor]) {
        guard !profile.isGeneral else { return (crowd, sound, 0, []) }
        var factors: [PersonalFactor] = []

        let personalCrowd = min(crowd * profile.crowd.multiplier, 1)
        if profile.crowd == .high && crowd >= 0.4 {
            factors.append(PersonalFactor(symbolName: "person.3", text: "사람이 많은 편이라 \(profile.displayName)에게는 더 버거울 수 있어요"))
        }

        let triggerLoad = SoundCategory.triggerCandidates.reduce(0) { total, category in
            total + (context.ratios[category] ?? 0) * profile.trigger(category).boost
        }
        let personalSound = min(sound * profile.loudness.multiplier * (1 + triggerLoad), 1)
        let basis = context.ratiosMeasured ? "실측에서" : "이런 곳은 보통"
        for category in SoundCategory.triggerCandidates where profile.trigger(category) != .fine {
            let ratio = context.ratios[category] ?? 0
            if ratio >= noticeableRatio {
                factors.append(PersonalFactor(symbolName: category.symbolName, text: "\(basis) \(category.title.particle("이", "가")) 자주 들려요 · \(profile.trigger(category).title)"))
            }
        }
        if profile.loudness == .high && sound >= 0.5 {
            factors.append(PersonalFactor(symbolName: "speaker.wave.3", text: "소리가 큰 편이에요 · 큰 소리에 예민해요"))
        }

        var penalty = 0.0
        if profile.brightLightSensitive && context.brightLight {
            penalty += brightLightPenalty
            factors.append(PersonalFactor(symbolName: "sun.max", text: "측정 때 조명이 많이 밝았어요"))
        }
        if profile.flickerSensitive && context.flicker {
            penalty += flickerPenalty
            factors.append(PersonalFactor(symbolName: "lightbulb.max", text: "측정 때 깜빡이는 조명이 있었어요"))
        }
        return (personalCrowd, personalSound, penalty, factors)
    }
}

extension String {
    var hasFinalConsonant: Bool {
        let closers = CharacterSet(charactersIn: ")]}>\"'”’").union(.whitespacesAndNewlines)
        let base = precomposedStringWithCanonicalMapping.trimmingCharacters(in: closers)
        guard let scalar = base.unicodeScalars.last else { return false }
        if (0xAC00...0xD7A3).contains(scalar.value) {
            return (scalar.value - 0xAC00) % 28 != 0
        }
        let last = Character(scalar).lowercased()
        return "013678lmn".contains(last)
    }

    func particle(_ withConsonant: String, _ withoutConsonant: String) -> String {
        self + (hasFinalConsonant ? withConsonant : withoutConsonant)
    }
}
