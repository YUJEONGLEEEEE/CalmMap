import SwiftUI

extension SensoryTier {
    var fill: Color {
        switch self {
        case .calm: Color.calmInk.opacity(0.18)
        case .moderate: Color.calmInk.opacity(0.55)
        case .intense: Color.calmStrong.opacity(0.92)
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
