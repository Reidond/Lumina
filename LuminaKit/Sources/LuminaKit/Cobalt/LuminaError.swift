import Foundation

/// User-facing error surface. All API failures, transport failures, and decoding
/// failures funnel through here so the UI can show one friendly message.
public enum LuminaError: Error, Equatable, Sendable {
    case invalidURL
    case notConfigured
    case auth(AuthReason)
    case turnstileRequired(sitekey: String?)
    case rateLimited(reset: Date?)
    case notFound
    case server(code: String?)
    case api(code: String, service: String?)
    case transport(String)
    case decoding(String)
    case unsupportedLocalProcessing(reason: String)
    case timedOut
    case canceled

    public enum AuthReason: Equatable, Sendable {
        case missingKey
        case invalidKey
        case generic
    }

    /// Build from a decoded Cobalt `error` payload, considering the HTTP status.
    public static func from(payload: CobaltErrorPayload, httpStatus: Int? = nil, reset: Date? = nil) -> LuminaError {
        let code = payload.code.lowercased()
        // A missing/invalid JWT or a turnstile error means the instance wants a Bearer token
        // minted via a Cloudflare Turnstile challenge.
        if code.contains("turnstile") || code.contains("jwt") {
            return .turnstileRequired(sitekey: nil)
        }
        if code.contains("api.auth") || httpStatus == 401 || httpStatus == 403 {
            if code.contains("missing") { return .auth(.missingKey) }
            if code.contains("invalid") { return .auth(.invalidKey) }
            return .auth(.generic)
        }
        if code.contains("rate") || httpStatus == 429 {
            return .rateLimited(reset: reset)
        }
        return .api(code: payload.code, service: payload.service)
    }

    /// Build from a bare HTTP status when there is no JSON error body.
    public static func from(httpStatus: Int, reset: Date? = nil) -> LuminaError {
        switch httpStatus {
        case 401, 403: return .auth(.generic)
        case 404: return .notFound
        case 429: return .rateLimited(reset: reset)
        case 500...599: return .server(code: nil)
        default: return .server(code: "\(httpStatus)")
        }
    }

    /// Map a `URLError` into transport/timeout/cancel cases.
    public static func from(urlError: URLError) -> LuminaError {
        switch urlError.code {
        case .timedOut: return .timedOut
        case .cancelled: return .canceled
        default: return .transport(urlError.localizedDescription)
        }
    }
}

extension LuminaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "That doesn’t look like a valid link.")
        case .notConfigured:
            return String(localized: "Set a Cobalt instance URL in Settings first.")
        case .auth(.missingKey):
            return String(localized: "This instance needs an API key. Add one in Settings.")
        case .auth(.invalidKey):
            return String(localized: "The API key was rejected. Check it in Settings.")
        case .auth(.generic):
            return String(localized: "Authorization failed for this instance.")
        case .turnstileRequired:
            return String(localized: "This instance requires a human-verification challenge.")
        case .rateLimited(let reset):
            if let reset {
                let secs = max(0, Int(reset.timeIntervalSinceNow.rounded()))
                return String(localized: "Rate limited. Try again in \(secs)s.")
            }
            return String(localized: "Rate limited. Please wait and try again.")
        case .notFound:
            return String(localized: "The instance couldn’t find that media.")
        case .server:
            return String(localized: "The instance had a problem. Try again later.")
        case .api(let code, _):
            return String(localized: "The instance returned an error (\(code)).")
        case .transport(let message):
            return message
        case .decoding:
            return String(localized: "The instance sent an unexpected response.")
        case .unsupportedLocalProcessing(let reason):
            return String(localized: "This media can’t be processed on-device: \(reason)")
        case .timedOut:
            return String(localized: "The request timed out.")
        case .canceled:
            return String(localized: "Canceled.")
        }
    }
}
