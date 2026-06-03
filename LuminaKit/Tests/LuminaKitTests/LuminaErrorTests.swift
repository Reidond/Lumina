import Foundation
import Testing
@testable import LuminaKit

@Suite("LuminaError mapping")
struct LuminaErrorTests {
    @Test func turnstileCodeMapsToTurnstile() {
        let e = LuminaError.from(payload: CobaltErrorPayload(code: "api.auth.turnstile.missing"))
        guard case .turnstileRequired = e else { Issue.record("expected turnstile, got \(e)"); return }
    }

    @Test func missingJWTMapsToTurnstile() {
        // The official public instance returns this when no Bearer token is supplied.
        let e = LuminaError.from(payload: CobaltErrorPayload(code: "error.api.auth.jwt.missing"))
        guard case .turnstileRequired = e else { Issue.record("expected turnstile, got \(e)"); return }
    }

    @Test func authCodesMap() {
        #expect(LuminaError.from(payload: .init(code: "api.auth.key.missing")) == .auth(.missingKey))
        #expect(LuminaError.from(payload: .init(code: "api.auth.key.invalid")) == .auth(.invalidKey))
        #expect(LuminaError.from(payload: .init(code: "api.auth.generic")) == .auth(.generic))
    }

    @Test func statusOnlyMapping() {
        #expect(LuminaError.from(httpStatus: 404) == .notFound)
        #expect(LuminaError.from(httpStatus: 401) == .auth(.generic))
        #expect(LuminaError.from(httpStatus: 503) == .server(code: nil))
    }

    @Test func urlErrorMapping() {
        #expect(LuminaError.from(urlError: URLError(.timedOut)) == .timedOut)
        #expect(LuminaError.from(urlError: URLError(.cancelled)) == .canceled)
        guard case .transport = LuminaError.from(urlError: URLError(.cannotFindHost)) else {
            Issue.record("expected transport"); return
        }
    }

    @Test func everyErrorHasAMessage() {
        let errors: [LuminaError] = [
            .invalidURL, .notConfigured, .auth(.missingKey), .auth(.invalidKey), .auth(.generic),
            .turnstileRequired(sitekey: nil), .rateLimited(reset: Date().addingTimeInterval(30)),
            .rateLimited(reset: nil), .notFound, .server(code: nil), .api(code: "x", service: nil),
            .transport("boom"), .decoding("d"), .unsupportedLocalProcessing(reason: "vp9"),
            .timedOut, .canceled,
        ]
        for e in errors {
            #expect(e.errorDescription?.isEmpty == false)
        }
    }
}
