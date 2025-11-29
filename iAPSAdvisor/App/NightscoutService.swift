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

enum DaySegment: String, CaseIterable, Identifiable {
    case earlyMorning
    case lateMorning
    case afternoon
    case evening

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .earlyMorning:
            return "Early Morning"
        case .lateMorning:
            return "Late Morning"
        case .afternoon:
            return "Afternoon"
        case .evening:
            return "Evening"
        }
    }

    var hourRange: Range<Int> {
        switch self {
        case .earlyMorning:
            return 0..<6
        case .lateMorning:
            return 6..<12
        case .afternoon:
            return 12..<18
        case .evening:
            return 18..<24
        }
    }

    static func segment(for date: Date, calendar: Calendar = .current) -> DaySegment {
        let hour = calendar.component(.hour, from: date)
        return DaySegment.allCases.first(where: { $0.hourRange.contains(hour) }) ?? .evening
    }
}

struct DaySegmentSummary: Identifiable {
    let segment: DaySegment
    var glucoseReadings: [BGReading] = []
    var insulinTreatments: [InsulinTreatment] = []
    var carbTreatments: [CarbTreatment] = []

    var id: DaySegment { segment }

    var averageGlucose: Double? {
        guard !glucoseReadings.isEmpty else { return nil }
        let total = glucoseReadings.reduce(0.0) { $0 + Double($1.sgv) }
        return total / Double(glucoseReadings.count)
    }

    var totalInsulin: Double {
        insulinTreatments.compactMap { $0.insulin }.reduce(0, +)
    }

    var totalCarbs: Double {
        carbTreatments.compactMap { $0.carbs }.reduce(0, +)
    }
}

enum NightscoutServiceError: Error, Equatable {
    case invalidURL
    case nonHTTPResponse
    case unsuccessfulStatus(Int)
}

private enum NightscoutDateParser {
    static let fractionalISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter
    }()

    static let isoFormatter = ISO8601DateFormatter()

    static func parse(_ string: String) -> Date? {
        if let date = fractionalISOFormatter.date(from: string) {
            return date
        }
        if let date = isoFormatter.date(from: string) {
            return date
        }
        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return fallback.date(from: string)
    }
}

class NightscoutService {
    private let baseURL: URL
    private let apiToken: String?
    private let componentsBuilder: (URL) -> URLComponents?
    private let dateFormatter: DateFormatter

    init(baseURL: URL, apiToken: String? = nil, componentsBuilder: @escaping (URL) -> URLComponents? = { url in
        URLComponents(url: url, resolvingAgainstBaseURL: false)
    }) {
        self.baseURL = baseURL
        self.apiToken = apiToken
        self.componentsBuilder = componentsBuilder
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter = formatter
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
            throw NightscoutServiceError.nonHTTPResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NightscoutServiceError.unsuccessfulStatus(httpResponse.statusCode)
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

    func fetchCarbIntake(startDate: String? = nil) async throws -> [CarbTreatment] {
        var items = [URLQueryItem(name: "find[eventType]", value: "Carb Correction")]
        if let start = startDate {
            items.append(URLQueryItem(name: "find[created_at][$gte]", value: start))
        }
        let request = try makeRequest(path: "api/v1/treatments.json", queryItems: items)
        let (data, _) = try await validatedResponse(for: request)
        return try JSONDecoder().decode([CarbTreatment].self, from: data)
    }

    func fetchSegmentedSummary(for date: Date = Date(), calendar: Calendar = .current) async throws -> [DaySegmentSummary] {
        let startOfDay = calendar.startOfDay(for: date)
        let startDate = dateFormatter.string(from: startOfDay)

        async let glucoseReadings = fetchBGReadings(startDate: startDate)
        async let insulinTreatments = fetchInsulinTreatments(startDate: startDate)
        async let carbTreatments = fetchCarbIntake(startDate: startDate)

        let (readings, insulin, carbs) = try await (glucoseReadings, insulinTreatments, carbTreatments)

        var summaryMap = Dictionary(uniqueKeysWithValues: DaySegment.allCases.map { ($0, DaySegmentSummary(segment: $0)) })

        for reading in readings {
            guard let date = NightscoutDateParser.parse(reading.dateString) else { continue }
            let segment = DaySegment.segment(for: date, calendar: calendar)
            if var summary = summaryMap[segment] {
                summary.glucoseReadings.append(reading)
                summaryMap[segment] = summary
            }
        }

        for treatment in insulin {
            guard let timestamp = treatment.created_at, let date = NightscoutDateParser.parse(timestamp) else { continue }
            let segment = DaySegment.segment(for: date, calendar: calendar)
            if var summary = summaryMap[segment] {
                summary.insulinTreatments.append(treatment)
                summaryMap[segment] = summary
            }
        }

        for carb in carbs {
            guard let timestamp = carb.created_at, let date = NightscoutDateParser.parse(timestamp) else { continue }
            let segment = DaySegment.segment(for: date, calendar: calendar)
            if var summary = summaryMap[segment] {
                summary.carbTreatments.append(carb)
                summaryMap[segment] = summary
            }
        }

        return DaySegment.allCases.compactMap { summaryMap[$0] }
    }
}

