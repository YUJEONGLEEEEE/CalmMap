import SwiftUI
import UIKit

extension Color {
    static let calmInk = Color(light: 0x294A6E, dark: 0xA9C4E2)
    static let calmOnInk = Color(light: 0xFFFFFF, dark: 0x0F1419)
    static let calmBackground = Color(light: 0xF4F6F8, dark: 0x0F1419)
    static let calmSurface = Color(light: 0xFFFFFF, dark: 0x19212A)
    static let calmTint = Color(light: 0xEAEFF4, dark: 0x1C2733)
    static let calmLine = Color(light: 0xE1E6EB, dark: 0x26303B)
    static let calmStrong = Color(light: 0x294A6E, dark: 0xC3D6EC)

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct CalmCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.calmSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: 16).strokeBorder(Color.calmLine)
                }
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 10, y: 2)
    }
}

struct CalmPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.calmOnInk)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.calmInk, in: RoundedRectangle(cornerRadius: 16))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

extension View {
    func calmCard(padding: CGFloat = 16) -> some View {
        modifier(CalmCard(padding: padding))
    }
}

extension ButtonStyle where Self == CalmPrimaryButtonStyle {
    static var calmPrimary: CalmPrimaryButtonStyle { CalmPrimaryButtonStyle() }
}
