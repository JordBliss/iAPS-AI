import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import NightscoutService

final class NightscoutServiceTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        _ = URLProtocol.registerClass(MockURLProtocol.self)
    }

    override class func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        super.tearDown()
    }

    func testFetchBGReadingsBuildsProperRequest() async throws {
        let startDate = "2021-01-01"
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "[{\"sgv\": 100, \"dateString\": \"2021-01-01T00:00:00Z\"}]".data(using: .utf8)!
            return (response, data)
        }

        let service = NightscoutService(baseURL: URL(string: "https://example.com")!)
        let readings = try await service.fetchBGReadings(startDate: startDate)

        XCTAssertEqual(readings.count, 1)
        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/entries.json")
        let components = URLComponents(url: capturedRequest!.url!, resolvingAgainstBaseURL: false)!
        let items = components.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "count", value: "100")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "find[dateString][$gte]", value: startDate)))
    }

    func testFetchInsulinTreatmentsUsesToken() async throws {
        let token = "secret"
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "[]".data(using: .utf8)!
            return (response, data)
        }

        let service = NightscoutService(baseURL: URL(string: "https://example.com")!, apiToken: token)
        _ = try await service.fetchInsulinTreatments()

        XCTAssertEqual(capturedRequest?.url?.path, "/api/v1/treatments.json")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "api-secret"), token)
        let components = URLComponents(url: capturedRequest!.url!, resolvingAgainstBaseURL: false)!
        let items = components.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "find[eventType]", value: "Insulin Injection")))
    }

    func testFetchBGReadingsDecodingError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "invalid".data(using: .utf8)!
            return (response, data)
        }

        let service = NightscoutService(baseURL: URL(string: "https://example.com")!)

        do {
            _ = try await service.fetchBGReadings(startDate: "2021-01-01")
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testFetchBGReadingsHandlesClientErrorResponse() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = NightscoutService(baseURL: URL(string: "https://example.com")!)

        do {
            _ = try await service.fetchBGReadings(startDate: "2021-01-01")
            XCTFail("Expected error for client response")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }
    }

    func testFetchBGReadingsHandlesServerErrorResponse() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = NightscoutService(baseURL: URL(string: "https://example.com")!)

        do {
            _ = try await service.fetchBGReadings(startDate: "2021-01-01")
            XCTFail("Expected error for server response")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }
    }

    func testMakeRequestThrowsForInvalidURL() {
        let service = NightscoutService(
            baseURL: URL(string: "https://example.com")!,
            componentsBuilder: { _ in nil }
        )
        XCTAssertThrowsError(try service.makeRequest(path: "api/v1/entries.json", queryItems: [])) { error in
            XCTAssertTrue(error is NightscoutServiceError)
        }
    }
}

private class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockURLProtocol", code: 0))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
