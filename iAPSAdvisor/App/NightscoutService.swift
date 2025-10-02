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

enum NightscoutServiceError: Error {
    case invalidURL
}

class NightscoutService {
    private let baseURL: URL
    private let apiToken: String?
    private let componentsBuilder: (URL) -> URLComponents?

    init(baseURL: URL, apiToken: String? = nil, componentsBuilder: @escaping (URL) -> URLComponents? = { url in
        URLComponents(url: url, resolvingAgainstBaseURL: false)
    }) {
        self.baseURL = baseURL
        self.apiToken = apiToken
        self.componentsBuilder = componentsBuilder
    }

    func makeRequest(path: String, queryItems: [URLQueryItem]) throws -> URLRequest {
        guard var components = componentsBuilder(baseURL.appendingPathComponent(path)) else {
            throw NightscoutServiceError.invalidURL
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw NightscoutServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        if let token = apiToken {
            request.addValue(token, forHTTPHeaderField: "api-secret")
        }
        return request
    }

    private func validatedResponse(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }

    func fetchBGReadings(startDate: String) async throws -> [BGReading] {
        let items = [
            URLQueryItem(name: "count", value: "100"),
            URLQueryItem(name: "find[dateString][$gte]", value: startDate)
        ]
        let request = try makeRequest(path: "api/v1/entries.json", queryItems: items)
        let (data, _) = try await validatedResponse(for: request)
        return try JSONDecoder().decode([BGReading].self, from: data)
    }

    func fetchInsulinTreatments(startDate: String? = nil) async throws -> [InsulinTreatment] {
        var items = [URLQueryItem(name: "find[eventType]", value: "Insulin Injection")]
        if let start = startDate {
            items.append(URLQueryItem(name: "find[created_at][$gte]", value: start))
        }
        let request = try makeRequest(path: "api/v1/treatments.json", queryItems: items)
        let (data, _) = try await validatedResponse(for: request)
        return try JSONDecoder().decode([InsulinTreatment].self, from: data)
    }

    func fetchCarbIntake() async throws -> [CarbTreatment] {
        let items = [URLQueryItem(name: "find[eventType]", value: "Carb Correction")]
        let request = try makeRequest(path: "api/v1/treatments.json", queryItems: items)
        let (data, _) = try await validatedResponse(for: request)
        return try JSONDecoder().decode([CarbTreatment].self, from: data)
    }
}

