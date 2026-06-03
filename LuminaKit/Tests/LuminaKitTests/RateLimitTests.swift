import Foundation
import Testing
@testable import LuminaKit

@Suite("RateLimit parsing")
struct RateLimitTests {
    @Test func parsesStandardHeaders() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let rl = RateLimit.parse(
            headers: ["RateLimit-Limit": "20", "RateLimit-Remaining": "5", "RateLimit-Reset": "60"],
            now: now)
        #expect(rl?.limit == 20)
        #expect(rl?.remaining == 5)
        #expect(rl?.reset == now.addingTimeInterval(60))
        #expect(rl?.isExhausted == false)
    }

    @Test func fallsBackToRetryAfter() {
        let now = Date(timeIntervalSince1970: 0)
        let rl = RateLimit.parse(headers: ["Retry-After": "15"], now: now)
        #expect(rl?.reset == now.addingTimeInterval(15))
    }

    @Test func caseInsensitiveHeaderNames() {
        let rl = RateLimit.parse(headers: ["ratelimit-remaining": "0"])
        #expect(rl?.remaining == 0)
        #expect(rl?.isExhausted == true)
    }

    @Test func returnsNilWhenAbsent() {
        #expect(RateLimit.parse(headers: ["Content-Type": "application/json"]) == nil)
    }
}
