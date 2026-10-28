import Foundation

enum NicknameValidator {
    static let limit = 10
    private static let invisible: Set<Unicode.Scalar> = ["\u{200B}", "\u{200C}", "\u{200D}", "\u{2060}", "\u{FEFF}"]

    static func normalized(_ name: String) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: name.unicodeScalars.filter { !invisible.contains($0) })
        return String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func count(_ name: String) -> Int {
        normalized(name).count
    }

    static func message(for name: String, existing: [String] = [], edited: Bool = true) -> String? {
        let trimmed = normalized(name)
        if trimmed.isEmpty {
            return edited ? "이름을 입력해 주세요." : nil
        }
        if trimmed.count > limit {
            return "이름은 최대 \(limit)자까지 입력할 수 있어요."
        }
        if existing.contains(where: { normalized($0).localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            return "이미 같은 이름의 프로필이 있어요."
        }
        return nil
    }
}
