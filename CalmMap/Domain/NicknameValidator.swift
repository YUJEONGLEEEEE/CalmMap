import Foundation

enum NicknameValidator {
    static let limit = 10

    static func count(_ name: String) -> Int {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    static func message(for name: String) -> String? {
        count(name) > limit ? "이름은 최대 \(limit)자까지 입력할 수 있어요." : nil
    }
}
