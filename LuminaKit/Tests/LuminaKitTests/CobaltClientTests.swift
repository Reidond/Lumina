import Foundation
import Testing
@testable import LuminaKit

@Suite("CobaltClient request/response/error")
struct CobaltClientTests {
    @Test func submitSendsAuthAndDecodesTunnel() async throws {
        let captured = CapturedRequest()
        let stub = MockURLProtocol.Stub(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: Data(#"{"status":"tunnel","url":"https://x.test/t","filename":"v.mp4"}"#.utf8),
            onRequest: { request, body in captured.set(request: request, body: body) }
        )
        let (client, id) = MockURLProtocol.makeClient(auth: .apiKey("KEY-123"), stub: stub)
        defer { MockURLProtocol.remove(id) }

        let response = try await client.submit(DownloadOptions().makeRequest(url: "https://y.test/v"))
        guard case let .tunnel(url, filename) = response else { Issue.record("expected tunnel"); return }
        #expect(url.absoluteString == "https://x.test/t")
        #expect(filename == "v.mp4")

        #expect(captured.authHeader == "Api-Key KEY-123")
        #expect(captured.contentType == "application/json")
        #expect(captured.accept == "application/json")
        #expect(captured.method == "POST")
        let bodyKeys = captured.bodyKeys
        #expect(bodyKeys.contains("url"))
    }

    @Test func notConfiguredThrows() async {
        let provider = StaticConfigurationProvider(nil)
        let client = CobaltClient(provider: provider, session: MockURLProtocol.session())
        await #expect(throws: LuminaError.notConfigured) {
            _ = try await client.submit(CobaltRequest(url: "u"))
        }
    }

    @Test func errorBodyMapsToLuminaError() async throws {
        let stub = MockURLProtocol.Stub(
            statusCode: 200,
            body: Data(#"{"status":"error","error":{"code":"api.auth.key.missing"}}"#.utf8))
        let (client, id) = MockURLProtocol.makeClient(stub: stub)
        defer { MockURLProtocol.remove(id) }
        await #expect(throws: LuminaError.auth(.missingKey)) {
            _ = try await client.submit(CobaltRequest(url: "u"))
        }
    }

    @Test func httpStatusMapping() async throws {
        let cases: [(Int, LuminaError)] = [
            (404, .notFound),
            (401, .auth(.generic)),
            (403, .auth(.generic)),
            (500, .server(code: nil)),
        ]
        for (status, expected) in cases {
            let stub = MockURLProtocol.Stub(statusCode: status, body: Data("nope".utf8))
            let (client, id) = MockURLProtocol.makeClient(stub: stub)
            await #expect(throws: expected) {
                _ = try await client.submit(CobaltRequest(url: "u"))
            }
            MockURLProtocol.remove(id)
        }
    }

    @Test func rateLimitParsedFromHeaders() async throws {
        let stub = MockURLProtocol.Stub(
            statusCode: 429,
            headers: ["RateLimit-Limit": "10", "RateLimit-Remaining": "0", "RateLimit-Reset": "30"],
            body: Data(#"{"status":"error","error":{"code":"api.rate.limit"}}"#.utf8))
        let (client, id) = MockURLProtocol.makeClient(stub: stub)
        defer { MockURLProtocol.remove(id) }

        do {
            _ = try await client.submit(CobaltRequest(url: "u"))
            Issue.record("expected throw")
        } catch let error as LuminaError {
            guard case let .rateLimited(reset) = error else { Issue.record("expected rateLimited, got \(error)"); return }
            #expect(reset != nil)
        }
        let last = await client.lastRateLimit
        #expect(last?.remaining == 0)
        #expect(last?.limit == 10)
    }

    @Test func instanceInfoDecodes() async throws {
        // startTime arrives as a STRING from the real public instance — must not fail decode.
        let body = #"""
        {"cobalt":{"version":"11.7.1","url":"https://x.test","startTime":"1779109885061",
         "turnstileSitekey":"0x4AAA","services":["youtube"]},
         "git":{"commit":"abc","branch":"main"}}
        """#
        let stub = MockURLProtocol.Stub(statusCode: 200, body: Data(body.utf8))
        let (client, id) = MockURLProtocol.makeClient(stub: stub)
        defer { MockURLProtocol.remove(id) }
        let info = try await client.fetchInstanceInfo(url: URL(string: "https://x.test")!)
        #expect(info.cobalt?.version == "11.7.1")
        #expect(info.cobalt?.startTime == "1779109885061")
        #expect(info.requiresTurnstile == true)
    }

    @Test func instanceInfoDecodesNumericStartTime() async throws {
        // …and as a NUMBER from other instances.
        let body = #"{"cobalt":{"version":"10.0","startTime":1779109885061}}"#
        let stub = MockURLProtocol.Stub(statusCode: 200, body: Data(body.utf8))
        let (client, id) = MockURLProtocol.makeClient(stub: stub)
        defer { MockURLProtocol.remove(id) }
        let info = try await client.fetchInstanceInfo(url: URL(string: "https://x.test")!)
        #expect(info.cobalt?.startTime == "1779109885061")
    }
}

/// Thread-safe capture box for the outgoing request.
final class CapturedRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var request: URLRequest?
    private var body: Data?

    func set(request: URLRequest, body: Data?) {
        lock.lock(); self.request = request; self.body = body; lock.unlock()
    }
    private func read<T>(_ f: (URLRequest?, Data?) -> T) -> T {
        lock.lock(); defer { lock.unlock() }; return f(request, body)
    }
    var authHeader: String? { read { req, _ in req?.value(forHTTPHeaderField: "Authorization") } }
    var contentType: String? { read { req, _ in req?.value(forHTTPHeaderField: "Content-Type") } }
    var accept: String? { read { req, _ in req?.value(forHTTPHeaderField: "Accept") } }
    var method: String? { read { req, _ in req?.httpMethod } }
    var bodyKeys: Set<String> {
        read { _, data in
            guard let data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return [] }
            return Set(obj.keys)
        }
    }
}
