import Foundation

enum AppConfig {
    static var apiHost: String { value(for: "CalmMapAPIHost") }
    static var appToken: String { value(for: "CalmMapAppToken") }

    private static func value(for key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
