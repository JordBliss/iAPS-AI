import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct BGReading: Codable {
    let sgv: Int
    let dateString: String
}

struct InsulinTreatment: Codable {
    let eventType: String
    let created_at: String?
    let insulin: Double?
}

struct CarbTreatment: Codable {
    let eventType: String
    let created_at: String?
    let carbs: Double?
}

class NightscoutService {
    private let baseURL: URL
    private let apiToken: String?

    init(baseURL: URL, apiToken: String? = nil) {
        self.baseURL = baseURL
        self.apiToken = apiToken
    }

    private func makeRequest(path: String, queryItems: [URLQueryItem]) -> URLRequest? {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = queryItems
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        if let token = apiToken {
            request.addValue(token, forHTTPHeaderField: "api-secret")
        }
        return request
    }

    func fetchBGReadings(startDate: String) async throws -> [BGReading] {
        let items = [
            URLQueryItem(name: "count", value: "100"),
            URLQueryItem(name: "find[dateString][$gte]", value: startDate)
        ]
        guard let request = makeRequest(path: "api/v1/entries.json", queryItems: items) else { return [] }
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([BGReading].self, from: data)
    }

    func fetchInsulinTreatments(startDate: String? = nil) async throws -> [InsulinTreatment] {
        var items = [URLQueryItem(name: "find[eventType]", value: "Insulin Injection")]
        if let start = startDate {
            items.append(URLQueryItem(name: "find[created_at][$gte]", value: start))
        }
        guard let request = makeRequest(path: "api/v1/treatments.json", queryItems: items) else { return [] }
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([InsulinTreatment].self, from: data)
    }

    func fetchCarbIntake() async throws -> [CarbTreatment] {
        let items = [URLQueryItem(name: "find[eventType]", value: "Carb Correction")]
        guard let request = makeRequest(path: "api/v1/treatments.json", queryItems: items) else { return [] }
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([CarbTreatment].self, from: data)
    }
}

