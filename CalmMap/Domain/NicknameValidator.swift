import Foundation

enum NicknameValidator {
    static let limit = 10
    private static let invisible: Set<Unicode.Scalar> = ["\u{115F}", "\u{1160}", "\u{200B}", "\u{200C}", "\u{200D}", "\u{2060}", "\u{2800}", "\u{3164}", "\u{FEFF}", "\u{FFA0}"]

    static func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func visible(_ name: String) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: name.unicodeScalars.filter { !invisible.contains($0) })
        return trimmed(String(scalars))
    }

    static func count(_ name: String) -> Int {
        trimmed(name).count
    }

    static func message(for name: String, existing: [String] = [], edited: Bool = true) -> String? {
        let shown = visible(name)
        if shown.isEmpty {
            return edited ? "이름을 입력해 주세요." : nil
        }
        if count(name) > limit {
            return "이름은 최대 \(limit)자까지 입력할 수 있어요."
        }
        if existing.contains(where: { visible($0).localizedCaseInsensitiveCompare(shown) == .orderedSame }) {
            return "이미 같은 이름의 프로필이 있어요."
        }
        return nil
    }
}
