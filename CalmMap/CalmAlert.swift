import Observation
import SwiftUI

@Observable
final class AlertCenter {
    struct Alert: Identifiable {
        let id = UUID()
        let systemImage: String
        let title: String
        let message: String
        let cancelTitle: String
        let actionTitle: String
        let action: () -> Void
    }

    private(set) var current: Alert?

    func present(
        systemImage: String,
        title: String,
        message: String,
        cancelTitle: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) {
        current = Alert(
            systemImage: systemImage,
            title: title,
            message: message,
            cancelTitle: cancelTitle,
            actionTitle: actionTitle,
            action: action
        )
    }

    func dismiss() {
        current = nil
    }
}

struct CalmAlertOverlay: ViewModifier {
    @Environment(AlertCenter.self) private var alerts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if alerts.current != nil {
                    Color(light: 0x0F1823, lightAlpha: 0.25, dark: 0x000000, darkAlpha: 0.45)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                if let alert = alerts.current {
                    CalmAlertCard(alert: alert) {
                        alerts.dismiss()
                    }
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
                    .id(alert.id)
                }
            }
            .animation(.spring(duration: 0.3), value: alerts.current?.id)
    }
}

private struct CalmAlertCard: View {
    let alert: AlertCenter.Alert
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: alert.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.calmInk)
                .frame(width: 52, height: 52)
                .background(Color.calmTint, in: Circle())
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(alert.title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(alert.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button(alert.cancelTitle) {
                    dismiss()
                }
                .buttonStyle(.calmSecondary)
                Button(alert.actionTitle) {
                    dismiss()
                    alert.action()
                }
                .buttonStyle(.calmPrimary)
            }
        }
        .padding(20)
        .frame(maxWidth: 320)
        .calmGlass(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 32)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

extension View {
    func calmAlertOverlay() -> some View {
        modifier(CalmAlertOverlay())
    }
}
