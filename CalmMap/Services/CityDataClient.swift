import Foundation

enum CityDataError: LocalizedError {
    case missingConfiguration
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "서버 설정이 없습니다."
        case .badStatus(let code):
            "데이터를 불러오지 못했습니다. (\(code))"
        }
    }
}

struct CityDataClient {
    var session: URLSession = .shared

    func fetchSnapshot() async throws -> CitySnapshot {
        let host = AppConfig.apiHost
        guard !host.isEmpty, let url = URL(string: "https://\(host)/v1/snapshot") else {
            throw CityDataError.missingConfiguration
        }
        var request = URLRequest(url: url)
        request.setValue(AppConfig.appToken, forHTTPHeaderField: "X-App-Token")
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw CityDataError.badStatus(http.statusCode)
        }
        return try JSONDecoder().decode(CitySnapshot.self, from: data)
    }
}
