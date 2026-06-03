import Foundation
import LuminaKit

/// A `URLProtocol` that returns canned responses, letting us drive `CobaltClient`
/// deterministically without hitting the network. A per-instance handler is selected
/// via a request header so concurrent tests don't share global state.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        var statusCode: Int = 200
        var headers: [String: String] = [:]
        var body: Data = Data()
        /// Optionally capture the outgoing request body for assertions.
        var onRequest: (@Sendable (URLRequest, Data?) -> Void)?
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var stubs: [String: Stub] = [:]

    static let headerKey = "X-Mock-Id"

    static func register(_ stub: Stub) -> String {
        let id = UUID().uuidString
        lock.lock(); stubs[id] = stub; lock.unlock()
        return id
    }

    static func remove(_ id: String) {
        lock.lock(); stubs[id] = nil; lock.unlock()
    }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let id = request.value(forHTTPHeaderField: Self.headerKey) ?? ""
        Self.lock.lock(); let stub = Self.stubs[id]; Self.lock.unlock()
        guard let stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        // Read the (possibly stream-based) request body for assertions.
        var bodyData = request.httpBody
        if bodyData == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let bufSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
            defer { buffer.deallocate(); stream.close() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufSize)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            bodyData = data
        }
        stub.onRequest?(request, bodyData)

        let response = HTTPURLResponse(
            url: request.url!, statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1", headerFields: stub.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension MockURLProtocol {
    /// Build a client whose session routes through a freshly-registered stub.
    static func makeClient(
        instanceURL: URL = URL(string: "https://cobalt.example.com")!,
        auth: CobaltConfiguration.Auth? = nil,
        stub: Stub
    ) -> (client: CobaltClient, stubId: String) {
        let id = register(stub)
        let provider = StaticConfigurationProvider(
            CobaltConfiguration(instanceURL: instanceURL, auth: auth))
        // Inject the stub id via a session-wide header.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.httpAdditionalHeaders = [headerKey: id]
        let session = URLSession(configuration: config)
        return (CobaltClient(provider: provider, session: session), id)
    }
}
