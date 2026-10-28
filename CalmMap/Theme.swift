import SwiftUI
import UIKit

extension Color {
    static let calmInk = Color(light: 0x294A6E, dark: 0xA9C4E2)
    static let calmOnInk = Color(light: 0xFFFFFF, dark: 0x0F1823)
    static let calmStrong = Color(light: 0x294A6E, dark: 0xC3D6EC)
    static let calmGlassFill = Color(light: 0xFFFFFF, lightAlpha: 0.36, dark: 0xFFFFFF, darkAlpha: 0.08)
    static let calmGlassEdge = Color(light: 0xFFFFFF, lightAlpha: 0.7, dark: 0xFFFFFF, darkAlpha: 0.26)
    static let calmGlow = Color(light: 0xFFFFFF, lightAlpha: 0.75, dark: 0xA9C4E2, darkAlpha: 0.35)
    static let calmTint = Color(light: 0x294A6E, lightAlpha: 0.12, dark: 0xA9C4E2, darkAlpha: 0.1)
    static let calmToast = Color(light: 0xE4EBF4, dark: 0x22344A)

    init(hex: UInt32) {
        self.init(light: hex, dark: hex)
    }

    init(light: UInt32, lightAlpha: CGFloat = 1, dark: UInt32, darkAlpha: CGFloat = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

struct CalmBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    private var gradient: [Color] {
        colorScheme == .dark
            ? [Color(hex: 0x1A2940), Color(hex: 0x0F1823), Color(hex: 0x142236)]
            : [Color(hex: 0xD7DFEA), Color(hex: 0xC6D1E1), Color(hex: 0xD1D9E6)]
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                ForEach(Array(Self.bands.enumerated()), id: \.offset) { _, band in
                    RoundedRectangle(cornerRadius: width * 0.22)
                        .strokeBorder(Color.calmGlow, lineWidth: 1.5)
                        .shadow(color: .calmGlow, radius: 10)
                        .frame(width: width * band.width, height: height * band.height)
                        .position(
                            x: width * (band.x + band.width / 2),
                            y: height * (band.y + band.height / 2)
                        )
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private static let bands: [(x: Double, y: Double, width: Double, height: Double)] = [
        (-0.3, 0.08, 0.7, 0.32),
        (0.3, 0.26, 0.9, 0.3),
        (-0.2, 0.52, 1.1, 0.26),
        (0.1, 0.72, 0.9, 0.34)
    ]
}

struct CalmGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .background(Color.calmGlassFill, in: shape)
            .overlay(shape.strokeBorder(Color.calmGlassEdge, lineWidth: 1))
            .shadow(color: Color(light: 0x28305A, dark: 0x000000).opacity(colorScheme == .dark ? 0.3 : 0.12), radius: 12, y: 4)
    }
}

struct CalmPrimaryButtonStyle: ButtonStyle {
    var fill: Color = .calmInk
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.calmOnInk)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                Capsule()
                    .fill(fill.opacity(0.94))
                    .overlay(
                        Capsule().fill(
                            LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
                        )
                    )
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .overlay(Capsule().strokeBorder(Color.calmGlassEdge, lineWidth: 1))
            .shadow(color: fill.opacity(0.3), radius: 10, y: 4)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
    }
}

struct CalmSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.calmInk)
            .frame(maxWidth: .infinity, minHeight: 52)
            .calmGlass(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension View {
    func calmGlass<S: InsettableShape>(_ shape: S) -> some View {
        modifier(CalmGlass(shape: shape))
    }

    func calmCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .calmGlass(RoundedRectangle(cornerRadius: 20))
    }

    func calmTintCard(padding: CGFloat? = nil, cornerRadius: CGFloat = 20) -> some View {
        self
            .padding(.all, padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.calmTint, in: RoundedRectangle(cornerRadius: cornerRadius))
            .calmGlass(RoundedRectangle(cornerRadius: cornerRadius))
    }

    func calmDetailSheet() -> some View {
        self
            .presentationDetents([.medium, .large])
            .presentationBackground { CalmBackdrop() }
    }
}

extension ButtonStyle where Self == CalmPrimaryButtonStyle {
    static var calmPrimary: CalmPrimaryButtonStyle { CalmPrimaryButtonStyle() }
    static var calmDestructive: CalmPrimaryButtonStyle { CalmPrimaryButtonStyle(fill: Color(light: 0xD93A30, dark: 0xE5554B)) }
}

extension ButtonStyle where Self == CalmSecondaryButtonStyle {
    static var calmSecondary: CalmSecondaryButtonStyle { CalmSecondaryButtonStyle() }
}
