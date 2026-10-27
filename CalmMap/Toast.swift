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
    }

    private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, style: Toast.Style = .info, duration: Duration = .seconds(2.5)) {
        let toast = Toast(message: message, style: style)
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
        content.overlay(alignment: .top) {
            if let toast = toasts.current {
                Label(toast.message, systemImage: toast.style.symbolName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.calmOnInk)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.calmInk.opacity(0.95), in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
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
