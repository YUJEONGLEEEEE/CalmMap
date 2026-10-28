import SwiftUI

extension SensoryTier {
    var fill: Color {
        switch self {
        case .calm: Color.calmInk.opacity(0.18)
        case .moderate: Color.calmInk.opacity(0.55)
        case .intense: Color.calmStrong.opacity(0.92)
        }
    }

    var soundTitle: String {
        switch self {
        case .calm: "조용한 편"
        case .moderate: "보통 수준"
        case .intense: "시끄러운 편"
        }
    }

    var foreground: Color {
        self == .calm ? Color.calmInk : Color.calmOnInk
    }
}

struct TierBadge: View {
    let tier: SensoryTier
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle().fill(tier.fill)
            Circle().strokeBorder(Color.calmInk, lineWidth: tier == .calm ? 1.5 : 0)
            Image(systemName: tier.symbolName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tier.foreground)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(tier.title)
    }
}

struct MeasuredSpotPin: View {
    let tier: SensoryTier
    var size: CGFloat = 22
    var name = "내가 측정한 곳"

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
        ZStack {
            shape.fill(Color(.systemBackground))
            shape.fill(tier.fill)
            shape.strokeBorder(Color.calmInk, lineWidth: tier == .calm ? 1.5 : 0)
            Image(systemName: "waveform")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(tier.foreground)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(name), 소리가 \(tier.soundTitle)")
    }
}
