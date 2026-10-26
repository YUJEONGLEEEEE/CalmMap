import Foundation

enum SoundCategory: String, CaseIterable, Codable, Identifiable {
    case suddenLoud
    case chime
    case crowd
    case babyCrying
    case traffic
    case music
    case quiet
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .suddenLoud: "갑작스러운 큰 소리"
        case .chime: "안내음·벨"
        case .crowd: "사람 소리·웅성임"
        case .babyCrying: "아이 울음"
        case .traffic: "교통·기계 소리"
        case .music: "음악"
        case .quiet: "조용함"
        case .other: "기타"
        }
    }

    var symbolName: String {
        switch self {
        case .suddenLoud: "exclamationmark.triangle"
        case .chime: "bell"
        case .crowd: "person.3"
        case .babyCrying: "figure.and.child.holdinghands"
        case .traffic: "car"
        case .music: "music.note"
        case .quiet: "leaf"
        case .other: "waveform"
        }
    }

    var loadWeight: Double {
        switch self {
        case .suddenLoud: 1.0
        case .babyCrying: 0.9
        case .chime: 0.8
        case .crowd: 0.7
        case .traffic: 0.6
        case .music: 0.5
        case .other: 0.3
        case .quiet: 0.0
        }
    }

    private static let suddenLoudLabels: Set<String> = [
        "siren", "ambulance_siren", "police_siren", "fire_engine_siren", "civil_defense_siren",
        "emergency_vehicle", "car_horn", "air_horn", "train_horn", "foghorn", "door_slam",
        "glass_breaking", "boom", "firecracker", "fireworks", "gunshot_gunfire", "alarm_clock",
        "smoke_detector", "beep", "reverse_beeps", "screaming", "shout", "yell", "hammer",
        "drill", "power_tool", "jackhammer", "thump_thud", "slap_smack", "whistling", "dog_bark"
    ]
    private static let chimeLabels: Set<String> = [
        "bell", "chime", "door_bell", "telephone_bell_ringing", "ringtone", "church_bell",
        "bicycle_bell", "wind_chime", "telephone"
    ]
    private static let crowdLabels: Set<String> = [
        "babble", "chatter", "crowd", "speech", "laughter", "belly_laugh", "giggling",
        "cheering", "applause", "clapping", "children_shouting", "booing", "battle_cry", "whispering"
    ]
    private static let babyLabels: Set<String> = ["baby_crying", "crying_sobbing"]
    private static let trafficLabels: Set<String> = [
        "traffic_noise", "car_passing_by", "engine", "engine_accelerating_revving", "engine_idling",
        "engine_starting", "engine_knocking", "bus", "truck", "motorcycle", "subway_metro", "train",
        "rail_transport", "railroad_car", "train_wheels_squealing", "aircraft", "airplane", "helicopter",
        "air_conditioner", "mechanical_fan", "vacuum_cleaner", "hair_dryer", "lawn_mower", "chainsaw",
        "saw", "blender", "water_pump", "vehicle_skidding", "race_car", "skateboard"
    ]
    private static let quietLabels: Set<String> = ["silence"]
    private static let musicKeywords = [
        "music", "singing", "guitar", "piano", "drum", "violin", "cello", "bass", "trumpet", "trombone",
        "saxophone", "flute", "clarinet", "organ", "synthesizer", "orchestra", "choir", "rapping",
        "harp", "ukulele", "banjo", "mandolin", "accordion", "harmonica", "percussion", "cymbal",
        "marimba", "xylophone", "vibraphone", "tambourine", "keyboard_musical", "electric_piano",
        "brass_instrument", "wind_instrument", "string_instrument", "zither", "sitar", "tabla"
    ]

    static func category(for label: String) -> SoundCategory {
        if suddenLoudLabels.contains(label) { return .suddenLoud }
        if chimeLabels.contains(label) { return .chime }
        if babyLabels.contains(label) { return .babyCrying }
        if crowdLabels.contains(label) { return .crowd }
        if trafficLabels.contains(label) { return .traffic }
        if quietLabels.contains(label) { return .quiet }
        if musicKeywords.contains(where: { label.contains($0) }) { return .music }
        return .other
    }
}

enum SoundScore {
    static let quietDecibels: Double = -60
    static let loudDecibels: Double = -20

    static func loudness(averageDecibels: Double) -> Double {
        let scaled = (averageDecibels - quietDecibels) / (loudDecibels - quietDecibels)
        return min(max(scaled, 0), 1)
    }

    static func score(ratios: [SoundCategory: Double], averageDecibels: Double, peakDecibels: Double) -> Double {
        let weighted = ratios.reduce(0) { $0 + $1.value * $1.key.loadWeight }
        let average = loudness(averageDecibels: averageDecibels)
        let peak = loudness(averageDecibels: peakDecibels)
        let combined = 0.45 * weighted + 0.4 * average + 0.15 * peak
        return min(max(combined, 0), 1)
    }
}
