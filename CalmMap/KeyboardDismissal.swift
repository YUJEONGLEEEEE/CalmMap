import UIKit

final class KeyboardDismissal: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissal()

    func install() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows where !(window.gestureRecognizers ?? []).contains(where: { $0.delegate === self }) {
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
        }
    }

    @objc private func dismissKeyboard(_ recognizer: UITapGestureRecognizer) {
        recognizer.view?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView {
                return false
            }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
