import SwiftUI

extension SensoryTier {
    var fill: Color {
        switch self {
        case .calm: Color.calmInk.opacity(0.18)
        case .moderate: Color.calmInk.opacity(0.5)
        case .intense: Color.calmInk.opacity(0.9)
        }
    }

    var foreground: Color {
        self == .calm ? Color.calmInk : .white
    }
}

extension Color {
    static let calmInk = Color(red: 0.16, green: 0.29, blue: 0.43)
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
