import Foundation

/// Decoded `GET /` instance metadata.
public struct InstanceInfo: Decodable, Sendable, Equatable {
    public let cobalt: Cobalt?
    public let git: Git?

    public struct Cobalt: Decodable, Sendable, Equatable {
        public let version: String?
        public let url: String?
        public let startTime: Double?
        public let turnstileSitekey: String?
        public let services: [String]?
    }

    public struct Git: Decodable, Sendable, Equatable {
        public let commit: String?
        public let branch: String?
        public let remote: String?
    }

    /// Whether this instance gates requests behind a Cloudflare Turnstile challenge.
    public var requiresTurnstile: Bool {
        (cobalt?.turnstileSitekey?.isEmpty == false)
    }
}
