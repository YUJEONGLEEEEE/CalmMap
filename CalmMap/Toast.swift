import Observation
import SwiftUI

@Observable
final class ToastCenter {
    struct Toast: Identifiable, Equatable {
        enum Style {
            case info
            case success
            case warning
        }

        let id = UUID()
        let message: String
        let style: Style
        var actionTitle: String?
        var action: (() -> Void)?

        static func == (lhs: Toast, rhs: Toast) -> Bool {
            lhs.id == rhs.id
        }
    }

    private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(
        _ message: String,
        style: Toast.Style = .info,
        duration: Duration = .seconds(2.5),
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        let toast = Toast(message: message, style: style, actionTitle: actionTitle, action: action)
        current = toast
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, self?.current?.id == toast.id else { return }
            self?.current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

private extension ToastCenter.Toast.Style {
    var symbolName: String {
        switch self {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        }
    }
}

struct ToastOverlay: ViewModifier {
    @Environment(ToastCenter.self) private var toasts

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast = toasts.current {
                HStack(spacing: 10) {
                    Label(toast.message, systemImage: toast.style.symbolName)
                    if let title = toast.actionTitle, let action = toast.action {
                        Button {
                            toasts.dismiss()
                            action()
                        } label: {
                            Text(title)
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(Color.calmOnInk.opacity(0.2), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.calmOnInk)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.calmInk.opacity(0.95), in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { toasts.dismiss() }
                    .accessibilityAddTraits(.isStaticText)
                    .id(toast.id)
            }
        }
        .animation(.spring(duration: 0.35), value: toasts.current)
    }
}

extension View {
    func toastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}
