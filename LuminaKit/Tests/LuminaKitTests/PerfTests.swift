import Foundation
import Testing
@testable import LuminaKit

@Suite("Performance budgets")
struct PerfTests {
    @Test func defaultRequestTimeoutIsBounded() {
        // SPEC: <2s initial response; a dead instance must not hang the UI for the 60s
        // URLSession default. We cap the POST at 15s.
        let config = CobaltConfiguration(instanceURL: URL(string: "https://x.test")!)
        #expect(config.requestTimeout <= 15)
    }

    @Test func submitIsFastAgainstAStub() async throws {
        let stub = MockURLProtocol.Stub(
            statusCode: 200,
            body: Data(#"{"status":"tunnel","url":"https://x.test/t","filename":"v.mp4"}"#.utf8))
        let (client, id) = MockURLProtocol.makeClient(stub: stub)
        defer { MockURLProtocol.remove(id) }

        let start = Date()
        _ = try await client.submit(CobaltRequest(url: "https://y.test/v"))
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 2.0)
    }
}
